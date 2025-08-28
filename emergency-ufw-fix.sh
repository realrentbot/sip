#!/bin/bash

# Экстренная защита FreePBX через UFW на сервере
# Защита от CVE-2024-45602
# Запускать на сервере FreePBX: ssh root@37.27.240.184

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# Ваш доверенный IP для веб-интерфейса
TRUSTED_IP="162.120.187.223"

echo "🔥 ЭКСТРЕННАЯ ЗАЩИТА FreePBX от CVE-2024-45602"
echo "🛡️  Ограничиваем доступ к веб-интерфейсу только для $TRUSTED_IP"
echo ""

# Проверка UFW
if ! command -v ufw &> /dev/null; then
    error "UFW не установлен! Установите: apt install ufw"
fi

# Показываем текущие правила
log "Текущие правила UFW:"
ufw status numbered

echo ""
warn "ВНИМАНИЕ: Сейчас будет ограничен доступ к веб-интерфейсу FreePBX!"
warn "Доступ к портам 8080/8443 будет только с IP: $TRUSTED_IP"
echo ""
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено пользователем"
    exit 0
fi

log "Удаляем старые правила для веб-портов..."
# Удаляем открытые правила для веб-портов (если есть)
ufw delete allow 8080/tcp 2>/dev/null || true
ufw delete allow 8443/tcp 2>/dev/null || true

log "Добавляем ограниченный доступ для $TRUSTED_IP..."
# Разрешаем доступ к веб-интерфейсу только с доверенного IP
ufw allow from $TRUSTED_IP to any port 8080 proto tcp comment "FreePBX Web - Trusted IP only"
ufw allow from $TRUSTED_IP to any port 8443 proto tcp comment "FreePBX HTTPS - Trusted IP only"

log "Проверяем SIP порты (должны быть открыты для всех)..."
# Проверяем что SIP порты открыты для всех
if ! ufw status | grep -q "5060.*ALLOW.*Anywhere"; then
    warn "Добавляем SIP порты..."
    ufw allow 5060/udp comment "SIP UDP"
    ufw allow 5060/tcp comment "SIP TCP" 
    ufw allow 5160/udp comment "PJSIP UDP"
    ufw allow 5160/tcp comment "PJSIP TCP"
    ufw allow 10000:20000/udp comment "RTP Media"
fi

log "Перезагружаем UFW..."
ufw reload

# Показываем итоговые правила
log "Итоговые правила UFW:"
ufw status numbered

echo ""
echo "=============================================="
log "🔒 Защита применена успешно!"
echo "=============================================="
echo ""
echo "✅ ЗАЩИЩЕНО:"
echo "   • FreePBX Web (8080) - доступен только с $TRUSTED_IP"
echo "   • FreePBX HTTPS (8443) - доступен только с $TRUSTED_IP"
echo ""
echo "✅ ОТКРЫТО для всех (нужно для телефонии):"
echo "   • SIP порты (5060 UDP/TCP, 5160 UDP/TCP)"
echo "   • RTP медиа порты (10000-20000 UDP)"
echo ""
warn "⚠️  ПРОВЕРЬТЕ:"
echo "1. Веб-интерфейс с вашего IP: http://37.27.240.184:8080"
echo "2. SIP регистрацию телефонов"
echo "3. Тестовый звонок между абонентами"
echo ""
echo "🆘 ОТКАТ (если что-то не работает):"
echo "   ufw allow 8080/tcp && ufw allow 8443/tcp && ufw reload"
echo "=============================================="