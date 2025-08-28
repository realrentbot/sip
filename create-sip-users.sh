#!/bin/bash

# Скрипт автоматического создания SIP пользователей в FreePBX
# Создает базовых пользователей для быстрого начала работы

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка что скрипт запущен на сервере FreePBX
check_freepbx() {
    if ! docker ps | grep -q freepbx-main; then
        error "FreePBX контейнер не запущен! Сначала запустите: ./deploy.sh start"
    fi
    
    if ! command -v mysql &> /dev/null && ! docker exec freepbx-main which mysql &> /dev/null; then
        error "MySQL клиент не найден в контейнере FreePBX"
    fi
}

# Ожидание готовности FreePBX
wait_for_freepbx() {
    log "Ожидание готовности FreePBX..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec freepbx-main curl -s http://localhost/admin/config.php | grep -q "FreePBX" 2>/dev/null; then
            log "FreePBX готов к работе"
            return 0
        fi
        
        info "Попытка $attempt/$max_attempts - ожидание готовности FreePBX..."
        sleep 10
        ((attempt++))
    done
    
    error "FreePBX не готов после $max_attempts попыток"
}

# Создание SIP пользователя через базу данных
create_sip_user() {
    local extension=$1
    local secret_md5=$2
    local display_name=$3
    
    log "Создание пользователя $extension ($display_name)..."
    
    # SQL запросы для создания SIP пользователя
    local sql_commands="
    -- Удаляем существующего пользователя если есть
    DELETE FROM sip WHERE id='$extension';
    DELETE FROM users WHERE extension='$extension';
    DELETE FROM devices WHERE id='$extension';
    
    -- Создаем SIP peer
    INSERT INTO sip (id, keyword, data, flags) VALUES 
    ('$extension', 'secret', '$secret_md5', 0),
    ('$extension', 'canreinvite', 'no', 1),
    ('$extension', 'context', 'from-internal', 2),
    ('$extension', 'host', 'dynamic', 3),
    ('$extension', 'trustrpid', 'yes', 4),
    ('$extension', 'sendrpid', 'no', 5),
    ('$extension', 'type', 'friend', 6),
    ('$extension', 'nat', 'force_rport,comedia', 7),
    ('$extension', 'port', '5060', 8),
    ('$extension', 'qualify', 'yes', 9),
    ('$extension', 'qualifyfreq', '60', 10),
    ('$extension', 'transport', 'udp,tcp,tls,ws', 11),
    ('$extension', 'avpf', 'no', 12),
    ('$extension', 'force_avp', 'no', 13),
    ('$extension', 'icesupport', 'no', 14),
    ('$extension', 'encryption', 'no', 15),
    ('$extension', 'disallow', 'all', 16),
    ('$extension', 'allow', 'ulaw,alaw,gsm,g726,g722', 17),
    ('$extension', 'dial', 'SIP/$extension', 18),
    ('$extension', 'mailbox', '$extension@device', 19),
    ('$extension', 'permit', '0.0.0.0/0.0.0.0', 20),
    ('$extension', 'deny', '0.0.0.0/0.0.0.0', 21),
    ('$extension', 'call-limit', '100', 22);
    
    -- Создаем пользователя
    INSERT INTO users (extension, password, name, voicemail, ringtimer, noanswer, recording, outboundcid, sipname, noanswer_cid, busy_cid, chanunavail_cid, noanswer_dest, busy_dest, chanunavail_dest) VALUES 
    ('$extension', '', '$display_name', 'default', 0, '', '', '', '$extension', '', '', '', '', '', '');
    
    -- Создаем устройство
    INSERT INTO devices (id, tech, dial, devicetype, user, description, emergency_cid) VALUES 
    ('$extension', 'sip', 'SIP/$extension', 'fixed', '$extension', '$display_name', '');
    "
    
    # Выполняем SQL команды в контейнере FreePBX
    if docker exec freepbx-main mysql -u root freepbxdb -e "$sql_commands"; then
        log "✅ Пользователь $extension создан успешно"
        return 0
    else
        error "❌ Ошибка создания пользователя $extension"
        return 1
    fi
}

# Перезагрузка конфигурации Asterisk
reload_asterisk() {
    log "Перезагрузка конфигурации Asterisk..."
    
    # Перезагружаем SIP конфигурацию
    docker exec freepbx-main asterisk -rx "sip reload" 2>/dev/null || true
    docker exec freepbx-main asterisk -rx "dialplan reload" 2>/dev/null || true
    docker exec freepbx-main asterisk -rx "module reload app_voicemail.so" 2>/dev/null || true
    
    # Альтернативно через fwconsole
    docker exec freepbx-main fwconsole reload 2>/dev/null || true
    
    log "Конфигурация перезагружена"
}

# Проверка созданных пользователей
verify_users() {
    log "Проверка созданных пользователей..."
    
    echo ""
    info "📋 Список SIP пользователей:"
    docker exec freepbx-main asterisk -rx "sip show peers" 2>/dev/null | grep -E "^(1001|1002|1003|1004|1005)" || true
    
    echo ""
    info "📊 Статистика пользователей:"
    local total_users=$(docker exec freepbx-main mysql -u root freepbxdb -se "SELECT COUNT(*) FROM sip WHERE id IN ('1001','1002','1003','1004','1005')" 2>/dev/null || echo "0")
    echo "Создано пользователей: $total_users/5"
}

# Основная функция
main() {
    echo "=============================================="
    log "🔧 Создание SIP пользователей для FreePBX"
    echo "=============================================="
    
    check_freepbx
    wait_for_freepbx
    
    # Массив пользователей: номер:MD5_пароль:имя:исходный_пароль
    declare -a users=(
        "1001:cc1202dcd73031907e2376bf35bf4ced:User 1001:password1001"
        "1002:13c975f7b08a9407cc73b264332ebf88:User 1002:password1002" 
        "1003:46c567dd72f67d06b455801dec4ce533:User 1003:password1003"
        "1004:4ddabbe9eaef3956e2c790897927458c:User 1004:password1004"
        "1005:41228bba6e2a63f98fe2286eec629c6f:User 1005:password1005"
    )
    
    info "Создание ${#users[@]} SIP пользователей..."
    
    # Создаем каждого пользователя
    local created=0
    declare -a created_users=()
    
    for user_data in "${users[@]}"; do
        IFS=':' read -r extension secret_md5 display_name original_password <<< "$user_data"
        
        if create_sip_user "$extension" "$secret_md5" "$display_name"; then
            ((created++))
            created_users+=("$extension:$original_password")
        fi
        
        # Небольшая пауза между созданием пользователей
        sleep 1
    done
    
    if [ $created -gt 0 ]; then
        reload_asterisk
        sleep 3
        verify_users
    fi
    
    echo ""
    echo "=============================================="
    log "🎉 Создание пользователей завершено!"
    echo "=============================================="
    echo ""
    info "📞 Созданные SIP аккаунты:"
    for user_info in "${created_users[@]}"; do
        IFS=':' read -r ext pwd <<< "$user_info"
        echo "   $ext - пароль: $pwd"
    done
    echo ""
    info "🔧 Настройки для SIP клиентов:"
    echo "   Сервер: 37.27.240.184"
    echo "   Порт: 5060"
    echo "   Транспорт: UDP"
    echo "   Логин: номер пользователя (например: 1001)"
    echo "   Пароль: соответствующий пароль из списка выше"
    echo ""
    info "📋 Тестовые звонки:"
    echo "   • Внутренние: 1001 → 1002, 1003, 1004, 1005"
    echo "   • Эхо тест: *43"
    echo "   • Музыка на удержании: *65"
    echo "   • Voicemail: *97"
    echo ""
    warn "⚠️  Важно:"
    echo "   • Пароли в базе данных хранятся в MD5 формате"
    echo "   • Для SIP телефонов используйте исходные пароли"
    echo "   • Полный список паролей в файле: sip-users-passwords.txt"
    echo "=============================================="
}

# Запуск основной функции
main "$@"