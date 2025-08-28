# 🚨 БЫСТРОЕ ИСПРАВЛЕНИЕ CVE-2024-45602

## Ваш IP: 162.120.187.223

### ⚡ НЕМЕДЛЕННО (на сервере):

```bash
# 1. Подключитесь к серверу
ssh root@37.27.240.184

# 2. Скачайте и запустите защиту
curl -o emergency-ufw-fix.sh https://raw.githubusercontent.com/realrentbot/sip/main/emergency-ufw-fix.sh
chmod +x emergency-ufw-fix.sh
./emergency-ufw-fix.sh
```

### 📋 Или вручную:

```bash
# Блокируем веб-порты для всех
ufw delete allow 8080/tcp
ufw delete allow 8443/tcp

# Открываем только для вашего IP
ufw allow from 162.120.187.223 to any port 8080 proto tcp
ufw allow from 162.120.187.223 to any port 8443 proto tcp

# Перезагружаем
ufw reload
```

### ✅ Проверка:
- Веб-интерфейс: http://37.27.240.184:8080 (работает только с вашего IP)
- SIP телефоны: должны регистрироваться как обычно
- Звонки: должны проходить нормально

### 🆘 Откат:
```bash
ufw allow 8080/tcp
ufw allow 8443/tcp
ufw reload
```