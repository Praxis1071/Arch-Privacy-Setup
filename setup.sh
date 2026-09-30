#!/usr/bin/env bash
#
# CachyOS / Arch Linux Privacy Auto-Setup
# - Boot'ta rastgele MAC adresi (macchanger)
# - Cloudflare WARP otomatik bağlantı
# - NetworkManager "sınırlı bağlantı" (?) simgesi düzeltmesi
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

VIRTUAL_IFACE_REGEX='^(lo|docker|veth|br-|virbr|tun|tap|wg|vboxnet|zt)'

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

INTERFACE=$(ip route | awk '/^default/ {print $5; exit}')

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
warn "ÖNEMLİ: macchanger servisi bu arayüze (\"$INTERFACE\") SABİTLENECEK."
warn "Daha sonra farklı bir ağ arayüzüne geçerseniz (ör. Wi-Fi'dan Ethernet'e,"
warn "ya da arayüz adı değişirse) bu script tekrar çalıştırılmalıdır, aksi"
warn "halde MAC değişimi artık kullanılmayan eski arayüz için yapılmaya devam eder."

# ---------------------------------------------------------------------------
# 2) Paketler
# ---------------------------------------------------------------------------
log "Pacman paketleri yükleniyor..."
sudo pacman -S macchanger --needed --noconfirm || die "macchanger kurulamadı."

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
# 3) NetworkManager'ın kendi MAC yönetimini devre dışı bırak
#    (macchanger ile çakışmaması için)
# ---------------------------------------------------------------------------
if require_cmd nmcli; then
    log "NetworkManager MAC yönetimi macchanger ile çakışmasın diye 'preserve' yapılıyor..."
    sudo mkdir -p /etc/NetworkManager/conf.d/
    printf '[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=preserve
ethernet.cloned-mac-address=preserve
' | sudo tee /etc/NetworkManager/conf.d/10-mac-preserve.conf > /dev/null
fi

# ---------------------------------------------------------------------------
# 4) MAC Changer systemd servisi
# ---------------------------------------------------------------------------
log "MAC Changer servisi oluşturuluyor ($INTERFACE için)..."

# systemd device unit adları özel karakterler için escape gerektirir
# (örn. arayüz adında '-' varsa). systemd-escape ile doğru isim üretilir.
ESCAPED_IFACE=$(systemd-escape "$INTERFACE")

printf '[Unit]
Description=macchanger on %s
Wants=network-pre.target
Before=network-pre.target NetworkManager.service
BindsTo=sys-subsystem-net-devices-%s.device
After=sys-subsystem-net-devices-%s.device

[Service]
Type=oneshot
ExecStart=/usr/bin/ip link set dev %s down
ExecStart=/usr/bin/macchanger -r %s
ExecStart=/usr/bin/ip link set dev %s up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
' "$INTERFACE" "$ESCAPED_IFACE" "$ESCAPED_IFACE" "$INTERFACE" "$INTERFACE" "$INTERFACE" \
    | sudo tee /etc/systemd/system/macchanger.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now macchanger.service || warn "macchanger.service başlatılamadı, logları kontrol edin: journalctl -u macchanger.service"

# ---------------------------------------------------------------------------
# 5) Cloudflare WARP
# ---------------------------------------------------------------------------
log "Cloudflare WARP servisi başlatılıyor..."
sudo systemctl enable --now warp-svc.service || die "warp-svc.service başlatılamadı."

for i in $(seq 1 15); do
    warp-cli --accept-tos status &> /dev/null && break
    sleep 1
done

warp-cli --accept-tos registration new &> /dev/null || true
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

TRACE="$(curl --silent --show-error --max-time 10 \
    https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)"

if grep -q '^warp=on$' <<<"$TRACE"; then
    log "WARP end-to-end bağlantısı doğrulandı."
    exit 0
fi

warn "WARP Connected görünüyor fakat HTTPS trace doğrulanamadı; yeniden bağlanılıyor."
warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
sleep 2
warp-cli --accept-tos connect >/dev/null 2>&1 || true

for _ in $(seq 1 15); do
    TRACE="$(curl --silent --show-error --max-time 5 \
        https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || true)"
    if grep -q '^warp=on$' <<<"$TRACE"; then
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
RemainAfterExit=yes

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
# 7) NetworkManager "sınırlı bağlantı" (?) ikonu düzeltmesi
# ---------------------------------------------------------------------------
log "NetworkManager captive-portal kontrolü kapatılıyor..."
sudo mkdir -p /etc/NetworkManager/conf.d/
printf '[connectivity]
enabled=false
' | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf > /dev/null

# WARP'ı önce ayır: NetworkManager restart sırasında yarım tunnel bırakma.
warp-cli --accept-tos disconnect >/dev/null 2>&1 || true

sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

sudo systemctl daemon-reload
sudo systemctl enable warp-autoconnect.service
sudo systemctl daemon-reload
sudo systemctl start warp-autoconnect.service

# ---------------------------------------------------------------------------
# 8) Durum kontrolü
# ---------------------------------------------------------------------------
echo
echo "======================================================================"
echo "[✓] Kurulum tamamlandı!"
echo
echo "Servis durumları:"
systemctl is-active macchanger.service        2>/dev/null | xargs -I{} echo "  - macchanger.service       : {}"
systemctl is-active warp-svc.service          2>/dev/null | xargs -I{} echo "  - warp-svc.service         : {}"
systemctl is-enabled warp-autoconnect.service 2>/dev/null | xargs -I{} echo "  - warp-autoconnect.service : {}"
echo
echo "MAC adresi:"
macchanger -s "$INTERFACE" 2>/dev/null || warn "macchanger -s $INTERFACE çalıştırılamadı."
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
echo "[!] HATIRLATMA: macchanger.service şu an sadece '$INTERFACE' arayüzü"
echo "    için ayarlandı. Wi-Fi <-> Ethernet arasında MAC randomizasyonunu"
echo "    yeni arayüze taşımak için scripti yeniden çalıştırın."
echo "======================================================================"
