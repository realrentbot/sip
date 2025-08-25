#!/bin/bash

# Скрипт безопасной настройки VPS для FreePBX
# Запускать с правами root: sudo bash security-setup.sh

echo "🔒 Настройка безопасности VPS для FreePBX..."

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Обновление системы
log "Обновляем систему..."
apt update && apt upgrade -y

# Установка базовых пакетов безопасности
log "Устанавливаем пакеты безопасности..."
apt install -y ufw fail2ban iptables-persistent

# Настройка UFW (Uncomplicated Firewall)
log "Настраиваем брандмауэр UFW..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH (измените порт если нужно)
ufw allow 22/tcp comment "SSH"

# FreePBX Web interface
ufw allow 8080/tcp comment "FreePBX Web"
ufw allow 8443/tcp comment "FreePBX HTTPS"

# SIP протоколы
ufw allow 5060/udp comment "SIP UDP"
ufw allow 5060/tcp comment "SIP TCP"
ufw allow 5160/udp comment "PJSIP UDP" 
ufw allow 5160/tcp comment "PJSIP TCP"

# RTP для голосового трафика
ufw allow 10000:20000/udp comment "RTP Media"

# Docker (если нужен внешний доступ)
ufw allow 2376/tcp comment "Docker"

# Активируем UFW
ufw --force enable
log "UFW активирован"

# Настройка fail2ban
log "Настраиваем fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[asterisk-iptables]
enabled = true
filter = asterisk
action = iptables-allports[name=ASTERISK]
logpath = /var/log/asterisk/security
maxretry = 5
bantime = 86400

[freepbx-iptables]
enabled = true
filter = freepbx
action = iptables-allports[name=FREEPBX]
logpath = /var/log/httpd/error_log
maxretry = 3
bantime = 3600
EOF

# Создаем фильтр для Asterisk
cat > /etc/fail2ban/filter.d/asterisk.conf << EOF
[Definition]
failregex = Registration from '.*' failed for '<HOST>:.*' - Wrong password
            Registration from '.*' failed for '<HOST>:.*' - No matching peer found
            Registration from '.*' failed for '<HOST>:.*' - Username/auth name mismatch
            Registration from '.*' failed for '<HOST>:.*' - Device does not match ACL
            Registration from '.*' failed for '<HOST>:.*' - Peer is not supposed to register
            Invalid extension .* in context .* from <HOST>
            Call from '.*' \(<HOST>:.*\) to extension '.*' rejected because extension not found in context
ignoreregex =
EOF

# Создаем фильтр для FreePBX
cat > /etc/fail2ban/filter.d/freepbx.conf << EOF
[Definition]
failregex = authentication failure.*rhost=<HOST>
            user .* authentication failure.*rhost=<HOST>
            \[client <HOST>\] user .* authentication failure
            \[client <HOST>\] user .* not found
ignoreregex =
EOF

# Перезапускаем fail2ban
systemctl restart fail2ban
systemctl enable fail2ban
log "fail2ban настроен и запущен"

# Настройка sysctl для безопасности
log "Настраиваем sysctl..."
cat >> /etc/sysctl.conf << EOF

# Сетевая безопасность
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# Оптимизация для VPS
vm.swappiness = 10
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sysctl -p
log "Параметры ядра обновлены"

# Создание пользователя для FreePBX (если нужен)
if ! id "asterisk" &>/dev/null; then
    log "Создаем пользователя asterisk..."
    useradd -r -s /bin/bash asterisk
fi

# Настройка ротации логов
log "Настраиваем ротацию логов..."
cat > /etc/logrotate.d/freepbx << EOF
/var/log/asterisk/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 asterisk asterisk
    postrotate
        /usr/sbin/asterisk -rx 'logger reload' >/dev/null 2>&1 || true
    endscript
}
EOF

# Создание скрипта для мониторинга
cat > /usr/local/bin/pbx-monitor.sh << 'EOF'
#!/bin/bash
# Простой мониторинг FreePBX

LOGFILE="/var/log/pbx-monitor.log"

check_service() {
    if docker ps | grep -q freepbx-pbx; then
        echo "[$(date)] FreePBX контейнер работает" >> $LOGFILE
    else
        echo "[$(date)] ALERT: FreePBX контейнер не работает!" >> $LOGFILE
        # Попытка перезапуска
        cd /opt/freepbx && docker-compose up -d
    fi
}

check_ports() {
    if ! netstat -tuln | grep -q :5060; then
        echo "[$(date)] ALERT: SIP порт 5060 не доступен!" >> $LOGFILE
    fi
    
    if ! netstat -tuln | grep -q :8080; then
        echo "[$(date)] ALERT: Web порт 8080 не доступен!" >> $LOGFILE
    fi
}

check_service
check_ports
EOF

chmod +x /usr/local/bin/pbx-monitor.sh

# Добавление мониторинга в cron
if ! crontab -l 2>/dev/null | grep -q pbx-monitor; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/pbx-monitor.sh") | crontab -
    log "Мониторинг добавлен в cron"
fi

# Настройка автоматических обновлений безопасности
log "Настраиваем автоматические обновления..."
apt install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

log "✅ Настройка безопасности завершена!"
log "🔍 Статус служб:"
systemctl status ufw --no-pager -l
systemctl status fail2ban --no-pager -l

echo ""
echo "📋 Следующие шаги:"
echo "1. Проверьте UFW статус: ufw status"
echo "2. Проверьте fail2ban: fail2ban-client status"
echo "3. Проверьте логи: tail -f /var/log/fail2ban.log"
echo "4. Перезагрузите сервер для применения всех изменений"
echo ""
echo "🚨 ВАЖНО: Убедитесь что у вас есть доступ по SSH перед перезагрузкой!"