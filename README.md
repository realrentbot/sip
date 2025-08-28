# FreePBX Deployment for Hetzner VPS

Простое и быстрое развертывание FreePBX на VPS сервере Hetzner.

## 🚀 Быстрый старт

### 1. Подключение к серверу
```bash
ssh root@YOUR_SERVER_IP
```

### 2. Загрузка проекта
```bash
git clone https://github.com/realrentbot/sip.git
cd sip
```

### 3. Запуск установки
```bash
sudo ./deploy.sh
```

**Все готово!** FreePBX будет доступен через 3-5 минут по адресу `http://37.27.240.184:8080`

## 📋 Что включено

- ✅ **Docker & Docker Compose** - автоматическая установка
- ✅ **FreePBX** - полнофункциональная PBX система
- ✅ **Firewall** - безопасная конфигурация UFW
- ✅ **SSL готовность** - поддержка HTTPS
- ✅ **Автозапуск** - запуск при перезагрузке сервера
- ✅ **Скрипты управления** - простые команды для администрирования

## 🔧 Управление системой

### Основные команды
```bash
./deploy.sh start    # Запуск FreePBX
./deploy.sh stop     # Остановка FreePBX  
./deploy.sh status   # Проверка статуса
./deploy.sh logs     # Просмотр логов
./deploy.sh update   # Обновление FreePBX
./deploy.sh backup   # Создание бэкапа
```

### Прямые скрипты (после установки)
```bash
cd /opt/freepbx

./start.sh    # Запуск
./stop.sh     # Остановка
./status.sh   # Статус
./logs.sh     # Логи
./backup.sh   # Бэкап
```

## 🌐 Доступ к системе

- **Web интерфейс:** http://37.27.240.184:8080
- **HTTPS:** https://37.27.240.184:8443  
- **SIP сервер:** 37.27.240.184:5060
- **SSH управление:** 37.27.240.184:2222

## 🔒 Сетевая безопасность

Автоматически настроенные порты:

| Порт | Протокол | Назначение |
|------|----------|------------|
| 22 | TCP | SSH |
| 8080 | TCP | FreePBX Web |
| 8443 | TCP | FreePBX HTTPS |
| 5060 | UDP/TCP | SIP |
| 5160 | UDP/TCP | PJSIP |
| 10000-20000 | UDP | RTP медиа |

## ⚙️ Первоначальная настройка FreePBX

1. **Откройте веб-интерфейс:** http://37.27.240.184:8080
2. **Создайте админа:** Следуйте мастеру установки
3. **Настройте модули:** Активируйте нужные модули
4. **Создайте абонентов:** Applications → Extensions
5. **Настройте маршрутизацию:** Connectivity → Inbound/Outbound Routes

### Рекомендуемые настройки

#### Базовые SIP абоненты:
- **Номер:** 1001, **Пароль:** SecurePass123!
- **Номер:** 1002, **Пароль:** SecurePass456!

#### Тестовые номера:
- **\*43** - Эхо тест
- **\*65** - Музыка на удержании
- **\*97** - Голосовая почта

## 📱 Подключение SIP клиентов

### Настройки для мобильных приложений:

**Основные параметры:**
- **Сервер:** 37.27.240.184
- **Порт:** 5060
- **Транспорт:** UDP
- **Логин:** 1001 (или ваш номер)
- **Пароль:** ваш пароль

**Рекомендуемые SIP клиенты:**
- **Android:** Linphone, CSipSimple
- **iOS:** Linphone, Bria Mobile
- **Windows:** MicroSIP, Linphone
- **Linux:** Linphone, Twinkle

## 🛠️ Расширенная конфигурация

### Изменение портов
Отредактируйте файл `.env` в `/opt/freepbx/`:
```bash
FREEPBX_HTTP_PORT=8080
FREEPBX_SIP_PORT=5060
RTP_START=10000
RTP_END=20000
```

### Настройка SSL
```bash
cd /opt/freepbx
# Добавьте SSL сертификаты в volumes
# Обновите docker-compose.yml для HTTPS
```

### Интеграция с провайдерами VoIP
1. **Settings → Asterisk SIP Settings**
2. **Connectivity → Trunks → Add SIP Trunk**
3. Настройте параметры вашего VoIP провайдера

## 📊 Мониторинг

### Проверка ресурсов
```bash
./deploy.sh status
```

### Просмотр логов
```bash
./deploy.sh logs
```

### Asterisk CLI
```bash
docker-compose exec freepbx-main asterisk -r
```

Полезные команды в Asterisk CLI:
```
sip show peers          # SIP абоненты
core show channels      # Активные каналы
reload                  # Перезагрузка конфигурации
```

## 🔄 Бэкап и восстановление

### Создание бэкапа
```bash
./deploy.sh backup
```
Бэкапы сохраняются в `/backup/freepbx/`

### Восстановление из бэкапа
1. Скопируйте файл бэкапа на сервер
2. В FreePBX: **Admin → Backup & Restore**
3. Загрузите файл бэкапа и восстановите

## 🚨 Устранение проблем

### FreePBX не запускается
```bash
./deploy.sh logs
docker-compose down
docker-compose up -d
```

### Проблемы с аудио (RTP)
- Проверьте настройки NAT в FreePBX
- Убедитесь что порты 10000-20000 открыты
- Проверьте настройки external IP

### Высокое использование ресурсов
```bash
# Ограничение памяти в docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '2.0'
```

## 📋 Требования к серверу

### Минимальные требования:
- **CPU:** 1 core (2 GHz)
- **RAM:** 2 GB
- **Диск:** 20 GB SSD
- **ОС:** Ubuntu 20.04+ / Debian 10+

### Рекомендуемые требования:
- **CPU:** 2 cores (2.4 GHz)
- **RAM:** 4 GB
- **Диск:** 40 GB SSD
- **Сеть:** 1 Gbps

### Hetzner VPS модели:
- **CX21:** Минимальная (2 GB RAM, 1 vCPU) - €4.90/мес
- **CX31:** Рекомендуемая (4 GB RAM, 2 vCPU) - €9.90/мес
- **CX41:** Продуктивная (8 GB RAM, 4 vCPU) - €19.90/мес

## 🔗 Полезные ссылки

- [FreePBX Wiki](https://wiki.freepbx.org/)
- [Asterisk Documentation](https://wiki.asterisk.org/)
- [Hetzner Cloud Console](https://console.hetzner.cloud/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 📞 Поддержка

При возникновении проблем:

1. **Проверьте логи:** `./deploy.sh logs`
2. **Проверьте статус:** `./deploy.sh status`
3. **Перезапустите:** `./deploy.sh stop && ./deploy.sh start`
4. **Создайте issue** в репозитории проекта

---

**Готово к работе!** 🎉 Ваша PBX система развернута и готова к использованию.