# Развертывание FreePBX на VPS

## 🚀 Быстрый старт

### 1. Подготовка VPS
```bash
# Обновляем систему
apt update && apt upgrade -y

# Устанавливаем Docker и Docker Compose
apt install -y docker.io docker-compose curl

# Запускаем Docker
systemctl start docker
systemctl enable docker
```

### 2. Развертывание FreePBX
```bash
# Клонируем/загружаем конфигурацию
git clone <your-repo> pbx-setup
cd pbx-setup

# Или создаем папку и копируем docker-compose.yml
mkdir freepbx-setup && cd freepbx-setup
# Скопировать docker-compose.yml в эту папку

# Запускаем контейнер
docker-compose up -d

# Проверяем статус
docker-compose ps
docker-compose logs -f freepbx
```

### 3. Первая настройка
1. Откройте в браузере: `http://IP_VPS:8080`
2. Дождитесь завершения установки (5-10 минут)
3. Создайте админский аккаунт
4. Войдите в FreePBX Admin Panel

## ⚙️ Настройка телефонии

### Создание SIP-аккаунтов
1. **Applications** → **Extensions**
2. **Add Extension** → **Chan SIP**
3. Заполните:
   - **Extension Number**: 101, 102, 103...
   - **Secret**: надежный пароль
   - **Display Name**: имя пользователя

### Настройка внутренней маршрутизации
- По умолчанию внутренние звонки работают автоматически
- 101 может звонить на 102, 103 и т.д.

## 📱 Подключение MicroSIP

### Настройки в MicroSIP:
```
Account name: Мой PBX
SIP server: IP_ВАШЕГО_VPS:5060
SIP proxy: IP_ВАШЕГО_VPS:5060
Username: 101 (номер из FreePBX)
Password: пароль из FreePBX
Domain: IP_ВАШЕГО_VPS
```

### Дополнительные настройки:
- **Transport**: UDP
- **Port**: 5060
- **Register**: включить

## 🔧 Порты и брандмауэр

### Открытые порты:
```bash
# UFW (если используется)
ufw allow 8080/tcp    # Web панель FreePBX
ufw allow 5060/udp    # SIP
ufw allow 5060/tcp    # SIP TCP
ufw allow 5160/udp    # PJSIP
ufw allow 10000:20000/udp  # RTP (голос)

# iptables альтернатива
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p udp --dport 5060 -j ACCEPT
iptables -A INPUT -p tcp --dport 5060 -j ACCEPT
iptables -A INPUT -p udp --dport 5160 -j ACCEPT
iptables -A INPUT -p udp --dport 10000:20000 -j ACCEPT
```

## 🔍 Диагностика

### Проверка работы:
```bash
# Статус контейнера
docker-compose ps

# Логи FreePBX
docker-compose logs -f freepbx

# Проверка портов
netstat -tulpn | grep -E "(5060|8080)"

# Тест SIP регистрации (изнутри контейнера)
docker exec -it freepbx-pbx asterisk -rx "sip show peers"
```

### Частые проблемы:
1. **Не открывается веб-панель**: проверьте порт 8080 в брандмауэре
2. **MicroSIP не регистрируется**: проверьте порт 5060/UDP
3. **Нет голоса**: проверьте RTP порты 10000-20000/UDP

## 📊 Ресурсы VPS

### Минимальные требования:
- **RAM**: 1GB (рекомендуется 2GB)
- **CPU**: 1 ядро
- **Диск**: 10GB
- **Сеть**: неограниченный трафик

### Оптимизация для слабых VPS:
```bash
# Ограничиваем использование памяти
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p
```

## 🔒 Безопасность

### Базовая защита:
1. Смените стандартный порт SSH (22 → 2222)
2. Используйте сложные пароли для SIP-аккаунтов
3. Настройте fail2ban в FreePBX
4. Ограничьте доступ к веб-панели по IP

### Обновления:
```bash
# Обновление образа FreePBX
docker-compose pull
docker-compose up -d
```