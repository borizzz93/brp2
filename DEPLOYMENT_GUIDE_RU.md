# Пошаговая инструкция по развертыванию Misago на Ubuntu 22.04

## Автор: MiniMax Agent
## Дата: 28 ноября 2025
## Версия: 1.0 (Исправленная)

## 📋 Системные требования

- **ОС**: Ubuntu 22.04 LTS
- **RAM**: Минимум 4GB (рекомендуется 8GB+)
- **Диск**: Минимум 20GB свободного места
- **CPU**: 2+ ядра
- **Сеть**: Статический IP адрес

## 🚀 Подготовка сервера

### 1. Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip htop nano
```

### 2. Настройка Firewall
```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp  # Альтернативный порт
sudo ufw --force enable
```

### 3. Установка Docker
```bash
# Удалить старые версии Docker (если есть)
sudo apt remove -y docker docker-engine docker.io containerd runc

# Установить Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Перезайти в систему или выполнить:
newgrp docker

# Установить Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Проверить установку
docker --version
docker-compose --version
```

### 4. Настройка системных параметров
```bash
# Увеличить лимиты файлов
echo '* soft nofile 65535' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 65535' | sudo tee -a /etc/security/limits.conf

# Настроить swap (если мало RAM)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 📦 Клонирование и подготовка проекта

### 1. Клонирование репозитория
```bash
cd /opt
sudo mkdir -p /opt/misago
sudo chown $USER:$USER /opt/misago
cd /opt/misago

git clone https://borizzz93/brp2.git .
```

### 2. Переход в директорию проекта
```bash
cd /opt/misago
```

### 3. Делаем скрипты исполняемыми
```bash
chmod +x *.sh
```

## ⚙️ Настройка конфигурации

### 1. Создание файла конфигурации
```bash
# Копируем пример конфигурации
cp .env.example .env

# Редактируем конфигурацию
nano .env
```

### 2. Пример содержимого .env файла
```bash
# Django Configuration
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
DJANGO_DEBUG=False
ALLOWED_HOSTS=benj.run.place,84.21.189.163,www.benj.run.place

# Database Configuration
POSTGRES_DB=misago
POSTGRES_USER=misago
POSTGRES_PASSWORD=secure_database_password_$(date +%s)
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Redis Configuration
REDIS_PASSWORD=secure_redis_password_$(date +%s)

# Email Configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=Misago <noreply@benj.run.place>

# SSL Configuration
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000

# Domain Configuration
DOMAIN_NAME=benj.run.place
SERVER_IP=84.21.189.163

# Celery Configuration
CELERY_BROKER_URL=redis://:secure_redis_password_$(date +%s)@redis:6379/0

# Optional: Sentry Error Monitoring
# SENTRY_DSN=https://your-sentry-dsn-here
```

## 🔧 Исправление критических ошибок

### 1. Проверка и создание директорий nginx
```bash
mkdir -p nginx/sites-enabled
ln -sf ../sites-available/misago nginx/sites-enabled/
```

### 2. Исправление опечатки в конфигурации nginx
```bash
# Проверяем файл
grep -n "run_place" nginx/sites-available/misago

# Если найдено, исправляем
sed -i 's/run_place/run.place/g' nginx/sites-available/misago
```

### 3. Исправление ошибки в docker-compose.prod.yaml
```bash
# Проверяем наличие ошибки
grep -n "POSTGROS_PASSWORD" docker-compose.prod.yaml

# Если найдено, исправляем
sed -i 's/POSTGROS_PASSWORD/POSTGRES_PASSWORD/g' docker-compose.prod.yaml
```

## 🚀 Развертывание приложения

### Вариант 1: Использование улучшенного скрипта
```bash
# Проверяем систему
./deploy_fixed.sh check

# Настраиваем окружение
./deploy_fixed.sh setup

# Развертываем приложение
./deploy_fixed.sh deploy
```

### Вариант 2: Ручное развертывание
```bash
# Проверяем Docker
docker --version
docker-compose --version

# Создаем необходимые директории
mkdir -p logs/nginx logs/app backups ssl

# Останавливаем существующие контейнеры (если есть)
docker-compose down 2>/dev/null || true

# Собираем и запускаем
docker-compose -f docker-compose.prod.yaml build --no-cache
docker-compose -f docker-compose.prod.yaml up -d

# Ждем запуска сервисов
sleep 60

# Проверяем статус
docker-compose -f docker-compose.prod.yaml ps

# Выполняем миграции
docker-compose -f docker-compose.prod.yaml exec web python manage.py migrate --noinput

# Собираем статические файлы
docker-compose -f docker-compose.prod.yaml exec web python manage.py collectstatic --noinput

# Создаем администратора
docker-compose -f docker-compose.prod.yaml exec web python manage.py createsuperuser
```

## 🔍 Проверка работоспособности

### 1. Проверка сервисов
```bash
# Статус всех контейнеров
docker-compose -f docker-compose.prod.yaml ps

# Логи приложения
docker-compose -f docker-compose.prod.yaml logs -f web

# Статистика ресурсов
docker stats
```

### 2. Проверка HTTP endpoints
```bash
# Проверяем доступность
curl -I http://localhost/health/
curl -I http://localhost:8000/health/

# Если используется альтернативный порт
curl -I http://localhost:8080/health/
```

### 3. Настройка домена
```bash
# В DNS настройках домена benj.run.place создаем A запись:
# benj.run.place -> 84.21.189.163
# www.benj.run.place -> 84.21.189.163
```

### 4. SSL сертификат для продакшена
```bash
# Установка Certbot
sudo apt install -y certbot

# Получение Let's Encrypt сертификата
sudo certbot certonly --standalone -d benj.run.place -d www.benj.run.place

# Копирование сертификатов
sudo cp /etc/letsencrypt/live/benj.run.place/fullchain.pem ./nginx/ssl/misago.crt
sudo cp /etc/letsencrypt/live/benj.run.place/privkey.pem ./nginx/ssl/misago.key
sudo chown $USER:$USER ./nginx/ssl/misago.*

# Перезапуск nginx
docker-compose -f docker-compose.prod.yaml restart nginx
```

## 📊 Мониторинг и обслуживание

### 1. Полезные команды
```bash
# Просмотр логов всех сервисов
docker-compose -f docker-compose.prod.yaml logs -f

# Логи конкретного сервиса
docker-compose -f docker-compose.prod.yaml logs -f web
docker-compose -f docker-compose.prod.yaml logs -f postgres
docker-compose -f docker-compose.prod.yaml logs -f redis

# Перезапуск сервисов
docker-compose -f docker-compose.prod.yaml restart

# Остановка сервисов
docker-compose -f docker-compose.prod.yaml stop

# Полное удаление
docker-compose -f docker-compose.prod.yaml down
```

### 2. Резервное копирование
```bash
# Создание бэкапа базы данных
./deploy_fixed.sh backup

# Или вручную
docker-compose -f docker-compose.prod.yaml exec postgres pg_dump -U misago misago > backup_$(date +%Y%m%d_%H%M%S).sql

# Бэкап медиафайлов
tar -czf media_backup_$(date +%Y%m%d_%H%M%S).tar.gz ./media_data
```

### 3. Восстановление из бэкапа
```bash
# Восстановление базы данных
docker-compose -f docker-compose.prod.yaml exec -T postgres psql -U misago misago < backup_file.sql

# Восстановление медиафайлов
tar -xzf media_backup_file.tar.gz
```

### 4. Обновление приложения
```bash
# Остановка сервисов
docker-compose -f docker-compose.prod.yaml down

# Обновление кода
git pull origin main

# Пересборка и запуск
docker-compose -f docker-compose.prod.yaml build --no-cache
docker-compose -f docker-compose.prod.yaml up -d

# Миграции (если нужны)
docker-compose -f docker-compose.prod.yaml exec web python manage.py migrate

# Пересборка статических файлов
docker-compose -f docker-compose.prod.yaml exec web python manage.py collectstatic --noinput
```

## 🐛 Решение проблем

### 1. Контейнеры не запускаются
```bash
# Проверяем логи
docker-compose -f docker-compose.prod.yaml logs [service_name]

# Проверяем порты
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Очищаем Docker
docker system prune -a
```

### 2. Проблемы с базой данных
```bash
# Проверяем подключение к БД
docker-compose -f docker-compose.prod.yaml exec postgres pg_isready -U misago

# Проверяем статус PostgreSQL
docker-compose -f docker-compose.prod.yaml exec postgres psql -U misago -c "SELECT version();"
```

### 3. Проблемы с Redis
```bash
# Проверяем Redis
docker-compose -f docker-compose.prod.yaml exec redis redis-cli ping
```

### 4. Проблемы с разрешениями
```bash
# Устанавливаем правильные разрешения
sudo chown -R $USER:$USER /opt/misago
chmod +x *.sh
```

## 📧 Конфигурация email

### 1. Gmail SMTP
```bash
# В .env файле
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
EMAIL_USE_TLS=True
```

### 2. Другие SMTP провайдеры
```bash
# SendGrid
EMAIL_HOST=smtp.sendgrid.net
EMAIL_PORT=587
EMAIL_HOST_USER=apikey
EMAIL_HOST_PASSWORD=your-sendgrid-api-key

# Mailgun
EMAIL_HOST=smtp.mailgun.org
EMAIL_PORT=587
EMAIL_HOST_USER=postmaster@sandbox.mailgun.org
EMAIL_HOST_PASSWORD=your-mailgun-password
```

## 🔒 Безопасность

### 1. Настройка fail2ban
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2. Обновление системы
```bash
# Регулярное обновление пакетов
sudo apt update && sudo apt upgrade -y

# Обновление Docker образов
docker-compose -f docker-compose.prod.yaml pull
docker-compose -f docker-compose.prod.yaml up -d
```

### 3. Настройка логирования
```bash
# Настройка logrotate
sudo nano /etc/logrotate.d/misago
```

Содержимое файла:
```
/opt/misago/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0644 $USER $USER
}
```

## 📈 Оптимизация производительности

### 1. Настройка PostgreSQL
```yaml
# Добавить в docker-compose.prod.yaml для postgres
command: postgres -c shared_buffers=256MB -c effective_cache_size=1GB -c maintenance_work_mem=64MB
```

### 2. Настройка Redis
```yaml
# Добавить в docker-compose.prod.yaml для redis
command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

### 3. Мониторинг ресурсов
```bash
# Установка htop и iotop
sudo apt install -y htop iotop

# Мониторинг в реальном времени
htop
iotop
```

## 🎯 Финальная проверка

После выполнения всех шагов убедитесь что:

1. ✅ Все контейнеры запущены: `docker-compose -f docker-compose.prod.yaml ps`
2. ✅ HTTP endpoints отвечают: `curl http://localhost/health/`
3. ✅ Админ панель доступна: `http://benj.run.place/admin/`
4. ✅ SSL сертификат установлен (для продакшена)
5. ✅ Email настройки работают
6. ✅ Резервное копирование настроено

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `docker-compose -f docker-compose.prod.yaml logs`
2. Проверьте системные ресурсы: `htop`, `df -h`
3. Проверьте сетевые подключения: `netstat -tlnp`
4. Обратитесь к документации проекта: https://misago.readthedocs.io

---

**Автор**: MiniMax Agent  
**Версия**: 1.0 (Исправленная)  
**Дата**: 28 ноября 2025  
**Лицензия**: GPL-2.0