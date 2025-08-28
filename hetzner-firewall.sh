#!/bin/bash

# Скрипт настройки Hetzner Cloud Firewall для FreePBX
# Защита от CVE-2024-45602 и других атак на веб-интерфейс
# 
# ВАЖНО: Замените YOUR_TRUSTED_IP на ваш реальный IP адрес!
# Узнать свой IP: curl ifconfig.me

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# НАСТРОЙКИ
TRUSTED_ADMIN_IP="162.120.187.223"  # Ваш IP для доступа к веб-интерфейсу  
SERVER_NAME="freepbx-server"        # Имя сервера в Hetzner Cloud

echo "🔥 Настройка Hetzner Cloud Firewall для FreePBX"
echo "⚠️  Защита от уязвимости CVE-2024-45602"
echo ""

# Проверка настроек
if [ "$TRUSTED_ADMIN_IP" = "YOUR_TRUSTED_IP" ]; then
    error "ОБЯЗАТЕЛЬНО укажите ваш реальный IP в переменной TRUSTED_ADMIN_IP!"
fi

info "Настройка защиты для IP: $TRUSTED_ADMIN_IP"

if ! command -v hcloud &> /dev/null; then
    error "hcloud CLI не установлен. Установите: https://github.com/hetznercloud/cli"
fi

log "Проверка текущих правил firewall..."

# Создание firewall правил (если еще не создан)
FIREWALL_NAME="freepbx-secure"

# Проверяем, существует ли уже firewall
if hcloud firewall list | grep -q "$FIREWALL_NAME"; then
    warn "Firewall '$FIREWALL_NAME' уже существует. Обновляем правила..."
    FIREWALL_ID=$(hcloud firewall list -o noheader | grep "$FIREWALL_NAME" | awk '{print $1}')
else
    log "Создаем новый firewall '$FIREWALL_NAME'..."
    FIREWALL_ID=$(hcloud firewall create --name "$FIREWALL_NAME" -o noheader | awk '{print $1}')
fi

log "Очищаем существующие правила..."
# Удаляем все существующие правила
hcloud firewall delete-rule $FIREWALL_ID --direction in --source-ips 0.0.0.0/0,::/0 --protocol tcp --port any 2>/dev/null || true
hcloud firewall delete-rule $FIREWALL_ID --direction in --source-ips 0.0.0.0/0,::/0 --protocol udp --port any 2>/dev/null || true

log "Настраиваем правила firewall..."

# 1. SSH - только с доверенного IP
info "Добавляем правило SSH (22/tcp) только с $TRUSTED_ADMIN_IP"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips "$TRUSTED_ADMIN_IP/32" \
    --protocol tcp \
    --port 22 \
    --description "SSH access from trusted IP"

# 2. FreePBX Web интерфейс - ТОЛЬКО с доверенного IP (защита от CVE-2024-45602)
info "Добавляем правило FreePBX Web (8080/tcp) только с $TRUSTED_ADMIN_IP"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips "$TRUSTED_ADMIN_IP/32" \
    --protocol tcp \
    --port 8080 \
    --description "FreePBX Web Admin - TRUSTED IP ONLY"

# 3. FreePBX HTTPS - ТОЛЬКО с доверенного IP
info "Добавляем правило FreePBX HTTPS (8443/tcp) только с $TRUSTED_ADMIN_IP"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips "$TRUSTED_ADMIN_IP/32" \
    --protocol tcp \
    --port 8443 \
    --description "FreePBX HTTPS Admin - TRUSTED IP ONLY"

# 4. SIP протокол - открыт для всех (нужен для работы телефонии)
info "Добавляем правило SIP (5060/udp) для всех"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips 0.0.0.0/0,::/0 \
    --protocol udp \
    --port 5060 \
    --description "SIP UDP for telephony"

info "Добавляем правило SIP (5060/tcp) для всех"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips 0.0.0.0/0,::/0 \
    --protocol tcp \
    --port 5060 \
    --description "SIP TCP for telephony"

# 5. PJSIP протокол - открыт для всех
info "Добавляем правило PJSIP (5160/udp) для всех"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips 0.0.0.0/0,::/0 \
    --protocol udp \
    --port 5160 \
    --description "PJSIP UDP for telephony"

info "Добавляем правило PJSIP (5160/tcp) для всех"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips 0.0.0.0/0,::/0 \
    --protocol tcp \
    --port 5160 \
    --description "PJSIP TCP for telephony"

# 6. RTP медиа порты - открыты для всех (нужны для голоса/видео)
info "Добавляем правило RTP (10000-20000/udp) для всех"
hcloud firewall add-rule $FIREWALL_ID \
    --direction in \
    --source-ips 0.0.0.0/0,::/0 \
    --protocol udp \
    --port 10000-20000 \
    --description "RTP media ports for audio/video"

# Применяем firewall к серверу
log "Применяем firewall к серверу '$SERVER_NAME'..."
if hcloud server list | grep -q "$SERVER_NAME"; then
    hcloud firewall apply-to-resource $FIREWALL_ID --type server --server "$SERVER_NAME"
    log "Firewall применен к серверу $SERVER_NAME"
else
    warn "Сервер '$SERVER_NAME' не найден. Примените firewall вручную:"
    echo "   hcloud firewall apply-to-resource $FIREWALL_ID --type server --server YOUR_SERVER_NAME"
fi

# Показываем итоговые правила
log "Текущие правила firewall:"
hcloud firewall describe $FIREWALL_ID

echo ""
echo "=============================================="
log "🔒 Firewall настроен успешно!"
echo "=============================================="
echo ""
info "🛡️  Защита:"
echo "   ✅ FreePBX веб-интерфейс доступен ТОЛЬКО с $TRUSTED_ADMIN_IP"
echo "   ✅ SSH доступен ТОЛЬКО с $TRUSTED_ADMIN_IP" 
echo "   ✅ SIP/PJSIP открыты для телефонии (5060, 5160)"
echo "   ✅ RTP порты открыты для голоса/видео (10000-20000)"
echo ""
warn "⚠️  ВАЖНО:"
echo "   • Доступ к FreePBX Admin: http://$TRUSTED_ADMIN_IP → http://server:8080"
echo "   • Если ваш IP изменится, обновите правила firewall!"
echo "   • SIP регистрация работает с любых IP (для телефонов)"
echo ""
info "📞 Проверка работы:"
echo "   1. Откройте http://37.27.240.184:8080 с вашего IP"
echo "   2. Проверьте SIP регистрацию телефонов"
echo "   3. Проверьте голосовые вызовы"
echo "=============================================="