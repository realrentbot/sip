#!/bin/bash

# SIP/FreePBX Deployment Script for Hetzner VPS
# Быстрое развертывание SIP системы на сервере

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_NAME="freepbx-sip"
INSTALL_DIR="/opt/freepbx"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
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

# Проверка root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Скрипт должен запускаться с правами root. Используйте: sudo $0"
    fi
}

# Определение ОС
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log "Обнаружена ОС: $OS $VER"
    else
        error "Не удается определить операционную систему"
    fi
}

# Установка Docker
install_docker() {
    log "Установка Docker..."
    
    # Удаление старых версий
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Обновление пакетов
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Добавление GPG ключа Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Установка Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Запуск и автозагрузка
    systemctl start docker
    systemctl enable docker
    
    # Проверка установки
    docker --version || error "Ошибка установки Docker"
    docker-compose --version || error "Ошибка установки Docker Compose"
    
    log "Docker установлен успешно"
}

# Настройка firewall
setup_firewall() {
    log "Настройка firewall..."
    
    # Установка ufw если не установлен
    apt-get install -y ufw
    
    # Базовые правила
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH
    ufw allow 22/tcp
    
    # Web интерфейсы
    ufw allow 8080/tcp  # FreePBX Web
    ufw allow 8443/tcp  # FreePBX HTTPS
    
    # SIP
    ufw allow 5060/udp  # SIP UDP
    ufw allow 5060/tcp  # SIP TCP
    ufw allow 5160/udp  # PJSIP UDP
    ufw allow 5160/tcp  # PJSIP TCP
    
    # RTP (медиа)
    ufw allow 10000:20000/udp
    
    # Включение firewall
    ufw --force enable
    
    log "Firewall настроен"
}

# Создание структуры проекта
create_project_structure() {
    log "Создание структуры проекта..."
    
    # Создание директорий
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Создание docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  freepbx:
    image: tiredofit/freepbx:latest
    container_name: freepbx-main
    restart: unless-stopped
    hostname: freepbx
    privileged: true
    environment:
      # Основные настройки
      - TZ=Europe/Moscow
      - ADMIN_DIRECTORY=admin
      
      # База данных
      - DB_EMBEDDED=TRUE
      
      # Сеть и порты  
      - HTTP_PORT=80
      - HTTPS_PORT=443
      - RTP_START=10000
      - RTP_FINISH=20000
      
      # Безопасность
      - ENABLE_TLS=FALSE
      - ENABLE_FAIL2BAN=TRUE
      
      # Производительность
      - ENABLE_CRON=TRUE
      - ENABLE_SMTP=FALSE
      
    ports:
      # Web интерфейс
      - "8080:80"
      - "8443:443"
      
      # SIP протоколы
      - "5060:5060/udp"
      - "5060:5060/tcp"
      - "5160:5160/udp"
      - "5160:5160/tcp"
      
      # RTP медиа потоки
      - "10000-20000:10000-20000/udp"
      
      # SSH для управления (опционально)
      - "2222:22"
      
    volumes:
      # Постоянное хранение данных
      - freepbx_data:/data
      - freepbx_logs:/var/log
      - freepbx_recordings:/var/spool/asterisk/monitor
      - freepbx_backup:/backup
      
    networks:
      - freepbx_network
      
    # Проверка здоровья
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/admin/config.php"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 300s

volumes:
  freepbx_data:
    driver: local
  freepbx_logs:
    driver: local
  freepbx_recordings:
    driver: local
  freepbx_backup:
    driver: local

networks:
  freepbx_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.18.0.0/16
EOF

    # Создание .env файла
    cat > .env << EOF
# FreePBX Configuration
COMPOSE_PROJECT_NAME=freepbx
TZ=Europe/Moscow

# Network settings
FREEPBX_HTTP_PORT=8080
FREEPBX_HTTPS_PORT=8443
FREEPBX_SIP_PORT=5060

# RTP Port range
RTP_START=10000
RTP_END=20000

# Server IP (will be set automatically)
SERVER_IP=$(curl -s ifconfig.me)
EOF

    log "Структура проекта создана в $INSTALL_DIR"
}

# Создание скриптов управления
create_management_scripts() {
    log "Создание скриптов управления..."
    
    # Скрипт старта
    cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Запуск FreePBX..."
docker-compose up -d
echo "FreePBX запущен!"
echo "Web интерфейс: http://$(curl -s ifconfig.me):8080"
echo "Для первоначальной настройки подождите 3-5 минут"
EOF

    # Скрипт остановки
    cat > stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Остановка FreePBX..."
docker-compose down
echo "FreePBX остановлен"
EOF

    # Скрипт обновления
    cat > update.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Обновление FreePBX..."
docker-compose pull
docker-compose down
docker-compose up -d
echo "FreePBX обновлен"
EOF

    # Скрипт бэкапа
    cat > backup.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
BACKUP_DIR="/backup/freepbx/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Создание бэкапа FreePBX..."
docker-compose exec freepbx-main fwconsole backup --backup
docker cp freepbx-main:/backup "$BACKUP_DIR/"
docker-compose exec freepbx-main mysqldump freepbxdb > "$BACKUP_DIR/database.sql"

echo "Бэкап создан в $BACKUP_DIR"
EOF

    # Скрипт логов
    cat > logs.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Логи FreePBX:"
docker-compose logs -f --tail=100 freepbx-main
EOF

    # Скрипт статуса
    cat > status.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "=== Статус FreePBX ==="
docker-compose ps
echo ""
echo "=== Использование ресурсов ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""
echo "=== Сетевые подключения ==="
netstat -tulpn | grep -E "(5060|8080|8443)" || echo "Нет активных подключений"
EOF

    # Установка прав на выполнение
    chmod +x *.sh
    
    log "Скрипты управления созданы"
}

# Запуск FreePBX
start_freepbx() {
    log "Запуск FreePBX..."
    
    cd "$INSTALL_DIR"
    
    # Скачивание образов
    info "Скачивание Docker образов (это может занять несколько минут)..."
    docker-compose pull
    
    # Запуск сервисов
    docker-compose up -d
    
    # Ожидание готовности
    info "Ожидание готовности FreePBX (до 5 минут)..."
    sleep 30
    
    # Проверка статуса
    if docker-compose ps | grep -q "Up"; then
        log "FreePBX запущен успешно!"
    else
        warn "FreePBX может быть еще не готов. Проверьте логи: $INSTALL_DIR/logs.sh"
    fi
}

# Вывод информации о развертывании
show_deployment_info() {
    local SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
    
    echo ""
    echo "=============================================="
    log "🎉 Развертывание FreePBX завершено!"
    echo "=============================================="
    echo ""
    info "📍 Доступ к системе:"
    echo "   🌐 Web интерфейс: http://$SERVER_IP:8080"
    echo "   🔒 HTTPS: https://$SERVER_IP:8443"
    echo "   📞 SIP сервер: $SERVER_IP:5060"
    echo ""
    info "🔧 Управление:"
    echo "   Запуск:    $INSTALL_DIR/start.sh"
    echo "   Остановка: $INSTALL_DIR/stop.sh"
    echo "   Логи:      $INSTALL_DIR/logs.sh"
    echo "   Статус:    $INSTALL_DIR/status.sh"
    echo "   Бэкап:     $INSTALL_DIR/backup.sh"
    echo ""
    info "⚠️  Первоначальная настройка:"
    echo "   1. Откройте http://$SERVER_IP:8080"
    echo "   2. Следуйте мастеру установки FreePBX"
    echo "   3. Создайте административную учетную запись"
    echo "   4. Настройте SIP абонентов"
    echo ""
    warn "Подождите 3-5 минут для полной инициализации системы"
    echo "=============================================="
}

# Основная функция
main() {
    echo "=============================================="
    log "🚀 Развертывание FreePBX на Hetzner VPS"
    echo "=============================================="
    
    check_root
    detect_os
    
    log "Начало установки..."
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        install_docker
    else
        log "Docker уже установлен"
    fi
    
    setup_firewall
    create_project_structure
    create_management_scripts
    start_freepbx
    
    show_deployment_info
}

# Обработка аргументов командной строки
case "${1:-}" in
    "install"|"")
        main
        ;;
    "start")
        cd "$INSTALL_DIR" && ./start.sh
        ;;
    "stop")
        cd "$INSTALL_DIR" && ./stop.sh
        ;;
    "status")
        cd "$INSTALL_DIR" && ./status.sh
        ;;
    "logs")
        cd "$INSTALL_DIR" && ./logs.sh
        ;;
    "update")
        cd "$INSTALL_DIR" && ./update.sh
        ;;
    "backup")
        cd "$INSTALL_DIR" && ./backup.sh
        ;;
    *)
        echo "Использование: $0 [install|start|stop|status|logs|update|backup]"
        echo ""
        echo "  install - Полная установка FreePBX (по умолчанию)"
        echo "  start   - Запуск FreePBX"
        echo "  stop    - Остановка FreePBX"
        echo "  status  - Показать статус"
        echo "  logs    - Показать логи"
        echo "  update  - Обновить FreePBX"
        echo "  backup  - Создать бэкап"
        exit 1
        ;;
esac