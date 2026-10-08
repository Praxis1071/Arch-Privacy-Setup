#!/usr/bin/env bash
#
# CachyOS / Arch Linux Privacy Auto-Setup
# - NetworkManager native MAC privacy (stable per Wi-Fi SSID / stable Ethernet)
# - Cloudflare WARP otomatik bağlantı
#
set -uo pipefail
# NOT: set -e kasıtlı olarak KULLANILMIYOR. warp-cli gibi araçlar zaten
# bağlıyken/kayıtlıyken sıfırdan farklı çıkış kodu döndürebiliyor; script
# bu yüzden erken durmasın diye her adım kendi hata kontrolünü yapıyor.

# ---------------------------------------------------------------------------
# 0) Root kontrolü
# ---------------------------------------------------------------------------
# Script 'sudo ./setup.sh' ile (yani doğrudan root olarak) çalıştırılırsa:
#   - 'makepkg' (yay derlemesi için) Arch güvenlik kuralları gereği root
#     olarak çalışmayı reddeder ve script orta yerde patlar.
# Bu yüzden script'in normal kullanıcı olarak başlatılmasını zorunlu kılıyoruz;
# gereken yerlerde zaten kendi içinde 'sudo' çağırıyor.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "[X] Lütfen bu scripti 'sudo' ile DEĞİL, normal kullanıcı olarak çalıştırın." >&2
    echo "[X] Script ihtiyaç duyduğu adımlarda kendisi 'sudo' isteyecektir." >&2
    exit 1
fi

VIRTUAL_IFACE_REGEX='^(lo|docker|veth|br-|virbr|tun|tap|wg|vboxnet|zt|CloudflareWARP)'

log()  { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
die()  { echo "[X] $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" &> /dev/null
}

# ---------------------------------------------------------------------------
# 1) Aktif / fiziksel ağ arayüzünü bul
# ---------------------------------------------------------------------------
log "Aktif ağ arayüzü aranıyor..."

INTERFACE=$(ip -o route show default 2>/dev/null     | awk '{print $5}'     | grep -Ev "$VIRTUAL_IFACE_REGEX"     | head -n 1)

if [ -z "${INTERFACE:-}" ] && require_cmd nmcli; then
    INTERFACE=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null         | awk -F: '$2 ~ /^(wifi|ethernet)$/ && $3 ~ /^(connected|connecting)$/ {print $1; exit}')
fi

if [ -z "${INTERFACE:-}" ]; then
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev "$VIRTUAL_IFACE_REGEX" | head -n 1)
fi

if [ -z "${INTERFACE:-}" ]; then
    die "Kullanılabilir bir ağ arayüzü bulunamadı. Elle ayarlamak için scripti düzenleyin."
fi

if echo "$INTERFACE" | grep -Eq "$VIRTUAL_IFACE_REGEX"; then
    die "Bulunan arayüz ($INTERFACE) sanal görünüyor. Güvenlik için işlem durduruldu."
fi

log "Kullanılacak ağ arayüzü: $INTERFACE"

# ---------------------------------------------------------------------------
# 2) Paketler
# ---------------------------------------------------------------------------
log "NetworkManager kontrol ediliyor..."
require_cmd nmcli || die "NetworkManager (nmcli) bulunamadı. Bu proje NetworkManager ile çalışır."


log "Cloudflare WARP kontrol ediliyor..."
if ! require_cmd warp-cli; then
    if ! require_cmd yay && ! require_cmd paru; then
        warn "AUR yardımcı programı (yay/paru) bulunamadı."
        echo

        # NOT: Script 'curl ... | bash' şeklinde pipe üzerinden çalıştırılırsa
        # standart girdi (stdin) pipe'a bağlı olur ve normal 'read -p' klavye
        # girdisi ALAMAZ (script sessizce donar ya da boş girdiyle devam eder).
        # Bunu önlemek için doğrudan terminalden (/dev/tty) okuyoruz. Eğer
        # gerçek bir terminal yoksa (ör. tamamen otomatik/headless bir CI
        # ortamı), güvenli tarafta kalıp kuruluma devam ETMİYORUZ.
        if [ -r /dev/tty ]; then
            read -p "[?] 'cloudflare-warp-bin' paketi AUR'da olduğu için bir AUR yardımcı programına ihtiyaç var. 'yay' şimdi kurulsun mu? [E/h]: " YAY_ONAY < /dev/tty
        else
            warn "Etkileşimli bir terminal (tty) bulunamadı, güvenlik gereği yay otomatik kurulmayacak."
            YAY_ONAY="h"
        fi

        case "$YAY_ONAY" in
            [Hh]* )
                die "'yay' veya 'paru' bulunamadı. 'cloudflare-warp-bin' paketini AUR üzerinden elle yükleyip scripti tekrar çalıştırın."
                ;;
            * )
                log "yay kuruluyor (tüm Arch tabanlı dağıtımlarla uyumlu, kaynaktan derleme yöntemi)..."
                sudo pacman -S --needed --noconfirm base-devel git \
                    || die "base-devel/git kurulamadı, yay derlenemez."

                YAY_BUILD_DIR=$(mktemp -d)
                git clone https://aur.archlinux.org/yay-bin.git "$YAY_BUILD_DIR/yay-bin" \
                    || die "yay-bin AUR deposu klonlanamadı (internet bağlantınızı kontrol edin)."

                (cd "$YAY_BUILD_DIR/yay-bin" && makepkg -si --needed --noconfirm) \
                    || die "yay derlenip kurulamadı."

                rm -rf "$YAY_BUILD_DIR"
                require_cmd yay || die "yay kurulumu tamamlandı ama komut bulunamadı, PATH'inizi kontrol edin."
                log "yay başarıyla kuruldu."
                ;;
        esac
    fi

    if require_cmd yay; then
        yay -S cloudflare-warp-bin --needed --noconfirm
    elif require_cmd paru; then
        paru -S cloudflare-warp-bin --needed --noconfirm
    else
        die "'yay' veya 'paru' bulunamadı. 'cloudflare-warp-bin' paketini AUR üzerinden elle yükleyip scripti tekrar çalıştırın."
    fi
fi

require_cmd warp-cli || die "warp-cli kurulumdan sonra bulunamadı."

# ---------------------------------------------------------------------------
# 3) NetworkManager native MAC privacy
# ---------------------------------------------------------------------------
# macchanger.service eski mimariden kaldırılır. NetworkManager'ın kendi
# cloned-mac-address mekanizması kullanılır; böylece MAC değişimi ile
# NetworkManager daemon restart'i veya ayrı bir systemd servisi arasında
# yarış oluşmaz.
log "Eski macchanger yapılandırması temizleniyor..."

if systemctl is-active --quiet macchanger.service || systemctl is-enabled --quiet macchanger.service 2>/dev/null; then
    sudo systemctl disable --now macchanger.service >/dev/null 2>&1 || true
fi
sudo rm -f /etc/systemd/system/macchanger.service
sudo rm -f /etc/NetworkManager/conf.d/10-mac-preserve.conf
sudo systemctl daemon-reload

log "NetworkManager native MAC gizliliği yapılandırılıyor..."
sudo install -d -m 0755 /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/20-arch-privacy-mac.conf > /dev/null <<'EOF'
[connection]
# Wi-Fi: aynı SSID için stabil, farklı SSID'ler için farklı yerel MAC.
wifi.cloned-mac-address=stable-ssid

# Ethernet: makineye/profil kimliğine göre stabil yerel MAC.
ethernet.cloned-mac-address=stable
EOF

# Yalnızca NetworkManager yapılandırmasını yeniden yükle. Daemon restart
# yapılmaz; bu özellikle WARP/tünel state'inin bozulmasını önler.
sudo nmcli general reload conf || die "NetworkManager yapılandırması yeniden yüklenemedi."

# 4) Cloudflare WARP
# ---------------------------------------------------------------------------
log "Cloudflare WARP servisi başlatılıyor..."
sudo systemctl enable --now warp-svc.service || die "warp-svc.service başlatılamadı."

for i in $(seq 1 15); do
    warp-cli --accept-tos status &> /dev/null && break
    sleep 1
done

if ! warp-cli --accept-tos registration show &> /dev/null; then
    warp-cli --accept-tos registration new &> /dev/null || true
fi
warp-cli --accept-tos mode warp &> /dev/null || true

# ---------------------------------------------------------------------------
# 6) WARP ağ dayanıklılığı
#
# Eski akışta WARP bağlandıktan sonra NetworkManager restart ediliyordu.
# Yeni akışta önce NetworkManager yapılandırması uygulanır, sonra WARP
# temiz bir sırayla bağlanır ve gerçek HTTPS trafiği doğrulanır.
# ---------------------------------------------------------------------------
log "WARP ağ kurtarma yardımcısı oluşturuluyor..."

sudo install -d -m 0755 /usr/local/libexec

sudo tee /usr/local/libexec/arch-privacy-warp-connect > /dev/null <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

log() { echo "[warp] $*"; }
warn() { echo "[warp] [!] $*" >&2; }

command -v warp-cli >/dev/null 2>&1 || exit 0

exec 9>/run/arch-privacy-warp.lock
if ! flock -n 9; then
    exit 0
fi

for _ in $(seq 1 30); do
    if ip route show default | grep -q '^default '; then
        break
    fi
    sleep 1
done

if ! ip route show default | grep -q '^default '; then
    warn "Default route hazır değil; WARP bağlantısı ertelendi."
    exit 0
fi

STATUS="$(warp-cli --accept-tos status 2>/dev/null || true)"

if ! grep -qi 'connected' <<<"$STATUS"; then
    log "WARP bağlanıyor..."
    warp-cli --accept-tos connect >/dev/null 2>&1 || true
fi

CONNECTED=0
for _ in $(seq 1 20); do
    STATUS="$(warp-cli --accept-tos status 2>/dev/null || true)"
    if grep -qi 'connected' <<<"$STATUS"; then
        CONNECTED=1
        break
    fi
    sleep 1
done

if [ "$CONNECTED" -ne 1 ]; then
    warn "WARP Connected durumuna geçemedi."
    exit 0
fi

trace_ok() {
    local trace
    trace="$(curl --silent --show-error --max-time 8 \
        https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)"
    grep -q '^warp=on$' <<<"$trace"
}

for _ in $(seq 1 3); do
    if trace_ok; then
        log "WARP end-to-end bağlantısı doğrulandı."
        exit 0
    fi
    sleep 2
done

warn "WARP Connected görünüyor fakat veri yolu doğrulanamadı; bir kez yeniden bağlanılıyor."
warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
sleep 2
warp-cli --accept-tos connect >/dev/null 2>&1 || true

for _ in $(seq 1 15); do
    if trace_ok; then
        log "WARP yeniden bağlandı ve trafik doğrulandı."
        exit 0
    fi
    sleep 1
done

warn "WARP doğrulanamadı. WARP ayrılıyor; normal internet korunuyor."
warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
exit 0
EOF

sudo chmod 0755 /usr/local/libexec/arch-privacy-warp-connect

log "WARP otomatik bağlanma servisi oluşturuluyor..."
sudo tee /etc/systemd/system/warp-autoconnect.service > /dev/null <<'EOF'
[Unit]
Description=Auto Connect Cloudflare WARP (network-safe)
After=warp-svc.service NetworkManager-wait-online.service network-online.target
Wants=warp-svc.service network-online.target
Requires=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/arch-privacy-warp-connect
TimeoutStartSec=90
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/warp-network-recover.service > /dev/null <<'EOF'
[Unit]
Description=Recover Cloudflare WARP after NetworkManager changes
After=warp-svc.service network-online.target
Wants=warp-svc.service network-online.target
Requires=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/arch-privacy-warp-connect
EOF

sudo tee /etc/NetworkManager/dispatcher.d/90-arch-privacy-warp > /dev/null <<'EOF'
#!/usr/bin/env bash
set -u

IFACE="${1:-}"
ACTION="${2:-}"

case "$ACTION" in
    up|reapply|dhcp4-change)
        ;;
    *)
        exit 0
        ;;
esac

case "$IFACE" in
    ""|lo|docker*|veth*|br-*|virbr*|tun*|tap*|wg*|vboxnet*|zt*)
        exit 0
        ;;
esac

systemctl start --no-block warp-network-recover.service >/dev/null 2>&1 || true
EOF

sudo chmod 0755 /etc/NetworkManager/dispatcher.d/90-arch-privacy-warp

# ---------------------------------------------------------------------------
# 7) Native MAC ayarını mevcut bağlantıda güvenli şekilde uygula
# ---------------------------------------------------------------------------
# Global default yalnızca profil explicit olarak başka bir değer istemiyorsa
# kullanılır. Mevcut aktif Wi-Fi profilinin explicit bir MAC politikası varsa
# kullanıcı ayarına dokunmayız; sonraki bağlantılarda global default uygulanır.
# Aktif bağlantı varsa, MAC'in hemen uygulanabilmesi için yalnızca o bağlantı
# kapatılıp tekrar açılır. NetworkManager daemon'u kesinlikle restart edilmez.
ACTIVE_TYPE="$(nmcli -g GENERAL.TYPE device show "$INTERFACE" 2>/dev/null || true)"
ACTIVE_CONNECTION="$(nmcli -g GENERAL.CONNECTION device show "$INTERFACE" 2>/dev/null || true)"

warp-cli --accept-tos disconnect >/dev/null 2>&1 || true

if [ "$ACTIVE_TYPE" = "wifi" ] && [ -n "$ACTIVE_CONNECTION" ] && [ "$ACTIVE_CONNECTION" != "--" ]; then
    PROFILE_MAC="$(nmcli -g 802-11-wireless.cloned-mac-address connection show "$ACTIVE_CONNECTION" 2>/dev/null || true)"

    if [ -z "$PROFILE_MAC" ] || [ "$PROFILE_MAC" = "--" ]; then
        log "Aktif Wi-Fi profili yeniden etkinleştiriliyor; stable-ssid MAC uygulanacak..."
        if ! nmcli connection down id "$ACTIVE_CONNECTION" >/dev/null 2>&1; then
            warn "Aktif Wi-Fi bağlantısı kontrollü olarak kapatılamadı; mevcut bağlantı korunuyor."
        elif ! nmcli connection up id "$ACTIVE_CONNECTION" ifname "$INTERFACE" >/dev/null 2>&1; then
            warn "Wi-Fi yeniden bağlanamadı; NetworkManager cihazı tekrar bağlamayı deniyor."
            nmcli device connect "$INTERFACE" >/dev/null 2>&1 || true
        fi
    else
        warn "Aktif Wi-Fi profili explicit MAC politikası kullanıyor: $PROFILE_MAC"
        warn "Kullanıcı profilini değiştirmiyorum; global stable-ssid ayarı sonraki uygun profillerde kullanılacak."
    fi
fi

sleep 2

CURRENT_MAC="$(ip -o link show dev "$INTERFACE" 2>/dev/null | awk '{print $17}' | tr '[:upper:]' '[:lower:]')"
if [ -z "$CURRENT_MAC" ]; then
    die "$INTERFACE için mevcut MAC adresi okunamadı."
fi

log "NetworkManager native MAC politikası etkin. Mevcut MAC: $CURRENT_MAC"

# 8) NetworkManager "sınırlı bağlantı" (?) ikonu düzeltmesi
# ---------------------------------------------------------------------------
# Captive-portal connectivity check'i WARP dayanıklılığı için gerekli değildir.
# NetworkManager'ın normal bağlantı durumunu değiştirmeden bırakılır.

sudo systemctl daemon-reload
sudo systemctl enable warp-autoconnect.service
sudo systemctl daemon-reload

# WARP recovery helper intentionally runs asynchronously. It may need to wait
# for a default route, WARP connection establishment, and end-to-end HTTPS
# verification. Blocking setup.sh here made a healthy setup look frozen.
if sudo systemctl start --no-block warp-autoconnect.service; then
    log "WARP otomatik bağlantı yardımcısı arka planda başlatıldı."
else
    warn "WARP otomatik bağlantı yardımcısı başlatılamadı; dispatcher daha sonra tekrar deneyecek."
fi

# ---------------------------------------------------------------------------
# 9) Durum kontrolü
# ---------------------------------------------------------------------------
echo
echo "======================================================================"
echo "[✓] Kurulum tamamlandı!"
echo
echo "Servis durumları:"
systemctl is-active warp-svc.service          2>/dev/null | xargs -I{} echo "  - warp-svc.service         : {}"
systemctl is-enabled warp-autoconnect.service 2>/dev/null | xargs -I{} echo "  - warp-autoconnect.service : {}"
echo
echo "MAC adresi:"
printf "  - Arayüz                  : %s\n" "$INTERFACE"
printf "  - Mevcut MAC             : %s\n" "$CURRENT_MAC"
printf "  - Wi-Fi politikası       : stable-ssid\n"
printf "  - Ethernet politikası    : stable\n"
echo
echo "WARP durumu:"
warp-cli --accept-tos status 2>/dev/null || true
echo
echo "End-to-end kontrol:"
if curl --silent --show-error --max-time 10 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q '^warp=on$'; then
    echo "  - Cloudflare WARP       : doğrulandı (warp=on)"
else
    echo "  - Cloudflare WARP       : aktif değil veya doğrulanamadı"
    echo "    Normal internetin bozulmaması için WARP yarım bağlantıda bırakılmaz."
fi
echo
echo "[i] NetworkManager ağ değişikliklerinde WARP otomatik olarak yeniden"
echo "    senkronize edilir. Bu özellikle Wi-Fi <-> Ethernet ve hotspot"
echo "    değişimlerinde eski tunnel/firewall durumunun kalmasını önler."
echo
echo "[i] WARP doğrulaması için Cloudflare'ın önerdiği trace yöntemi kullanılır:"
echo "    curl -s https://www.cloudflare.com/cdn-cgi/trace"
echo "    Çıktıda 'warp=on' görünmelidir."
echo
echo "[i] MAC yönetimi artık NetworkManager tarafından native olarak yapılır."
echo "    Wi-Fi: aynı SSID'de stabil, farklı SSID'lerde farklı MAC."
echo "    Ethernet: stabil native MAC."
echo "    NetworkManager daemon'u MAC değişimi için restart edilmez."
echo "======================================================================"
