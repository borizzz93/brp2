# pylint: disable=line-too-long
"""
Production Django settings for Misago deployment on Ubuntu 22.04
Optimized for production environment with security, performance, and monitoring.

Generated for deployment on: benj.run.place (84.21.189.163)
"""

import os
from decouple import config
from misago import discover_plugins
from misago.settings import *

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


# SECURITY WARNING: keep the secret key used in production secret!
# This should be set via environment variable DJANGO_SECRET_KEY
SECRET_KEY = config('DJANGO_SECRET_KEY', default='CHANGE_ME_IN_PRODUCTION')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = config('DJANGO_DEBUG', default=False, cast=bool)


# A list of strings representing the host/domain names that this Django site can serve.
# Set this to your domain names to prevent host header attacks
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='benj.run.place,84.21.189.163', cast=lambda v: [s.strip() for s in v.split(',')])


# Database
# https://docs.djangoproject.com/en/1.11/ref/settings/#databases

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": config('POSTGRES_DB', default='misago'),
        "USER": config('POSTGRES_USER', default='misago'),
        "PASSWORD": config('POSTGRES_PASSWORD'),
        "HOST": config('POSTGRES_HOST', default='postgres'),
        "PORT": config('POSTGRES_PORT', default=5432, cast=int),
        "OPTIONS": {
            "charset": "utf8",
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
        "CONN_MAX_AGE": 60,
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"


# Caching
# Use Redis for production caching
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": config('REDIS_URL', default='redis://localhost:6379/1'),
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
            "CONNECTION_POOL_KWARGS": {
                "max_connections": 50,
                "retry_on_timeout": True,
            },
            "COMPRESSOR": "django_redis.compressors.zlib.ZlibCompressor",
            "SERIALIZER": "django_redis.serializers.msgpack.MSGPackSerializer",
        },
        "KEY_PREFIX": "misago:",
        "TIMEOUT": 300,
    }
}

# Session cache
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"

# Password validation
# https://docs.djangoproject.com/en/1.11/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
        "OPTIONS": {"user_attributes": ["username", "email"]},
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 12},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.PersonalDictionaryValidator",
        "OPTIONS": {"word_list": ["misago", "password", "123456", "admin"]},
    },
]


# Security Settings
# https://docs.djangoproject.com/en/4.2/ref/settings/#security

# HTTPS settings
SECURE_SSL_REDIRECT = config('SECURE_SSL_REDIRECT', default=True, cast=bool)
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# HSTS (HTTP Strict Transport Security)
SECURE_HSTS_SECONDS = config('SECURE_HSTS_SECONDS', default=31536000, cast=int)
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Content Security Policy
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'

# Cookie security
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Strict'
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = True
CSRF_COOKIE_SAMESITE = 'Strict'

# Referrer policy
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"

# Proxy headers
USE_X_FORWARDED_HOST = True
USE_X_FORWARDED_PORT = True


# Internationalization
# https://docs.djangoproject.com/en/1.11/topics/i18n/

LANGUAGE_CODE = config('LANGUAGE_CODE', default='en-us')

TIME_ZONE = config('TIME_ZONE', default='UTC')

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.11/howto/static-files/

STATIC_URL = config('STATIC_URL', default='/static/')

# User uploads (Avatars, Attachments, files uploaded in other Django apps, etc.)
MEDIA_URL = config('MEDIA_URL', default='/media/')

# Static files collection
STATIC_ROOT = config('STATIC_ROOT', default='/app/static')

# Media files storage
MEDIA_ROOT = config('MEDIA_ROOT', default='/app/media')

# Additional static files locations
STATICFILES_DIRS = []

# Static files finders
STATICFILES_FINDERS = [
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
]


# Email configuration
# https://docs.djangoproject.com/en/1.11/ref/settings/#email-backend

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'

EMAIL_HOST = config('EMAIL_HOST', default='localhost')

EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)

EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')

EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')

EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)

DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='Misago <noreply@benj.run.place>')

SERVER_EMAIL = config('SERVER_EMAIL', default='Misago <noreply@benj.run.place>')


# Logging configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/app/logs/misago.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
        'misago': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
        'celery': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}


# Application definition

AUTH_USER_MODEL = "misago_users.User"

AUTHENTICATION_BACKENDS = ["misago.users.authbackends.MisagoBackend"]

CSRF_FAILURE_VIEW = "misago.core.errorpages.csrf_failure"

PLUGINS_DIRECTORY = os.environ.get("MISAGO_PLUGINS")

INSTALLED_PLUGINS = discover_plugins(PLUGINS_DIRECTORY)

# Combine Misago's default installed apps with plugins
INSTALLED_APPS = [
    *INSTALLED_PLUGINS,
    *INSTALLED_APPS,
]

# Internal IPs for debug toolbar (only in development)
INTERNAL_IPS = []

# URL redirects
LOGIN_REDIRECT_URL = "misago:index"
LOGIN_URL = "misago:login"
LOGOUT_URL = "misago:logout"

# Middleware - removed debug toolbar for production
MIDDLEWARE = MISAGO_MIDDLEWARE

ROOT_URLCONF = "devproject.urls"

# Social Auth
SOCIAL_AUTH_STRATEGY = "misago.socialauth.strategy.MisagoStrategy"

SOCIAL_AUTH_PIPELINE = (
    "social_core.pipeline.social_auth.social_details",
    "social_core.pipeline.social_auth.social_uid",
    "social_core.pipeline.social_auth.social_user",
    "misago.socialauth.pipeline.associate_by_email",
    "misago.socialauth.pipeline.validate_ip_not_banned",
    "misago.socialauth.pipeline.validate_user_not_banned",
    "misago.socialauth.pipeline.get_username",
    "misago.socialauth.pipeline.create_user_with_form",
    "social_core.pipeline.social_auth.associate_user",
    "social_core.pipeline.social_auth.load_extra_data",
    "misago.socialauth.pipeline.require_activation",
)

SOCIAL_AUTH_JSONFIELD_ENABLED = True

# Template configuration
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": TEMPLATE_CONTEXT_PROCESSORS,
        },
    }
]

WSGI_APPLICATION = "devproject.wsgi.application"


# Django Rest Framework - optimized for production
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "misago.core.rest_permissions.IsAuthenticatedOrReadOnly"
    ],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "EXCEPTION_HANDLER": "misago.core.exceptionhandler.handle_api_exception",
    "UNAUTHENTICATED_USER": "misago.users.models.AnonymousUser",
    "URL_FORMAT_OVERRIDE": None,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle"
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/hour",
        "user": "1000/hour"
    }
}


# Celery Configuration for production
# http://docs.celeryproject.org/en/latest/userguide/configuration.html

CELERY_BROKER_URL = config('CELERY_BROKER_URL', default='redis://localhost:6379/0')

CELERY_RESULT_BACKEND = config('CELERY_RESULT_BACKEND', default='redis://localhost:6379/0')

CELERY_ACCEPT_CONTENT = ['json']

CELERY_TASK_SERIALIZER = 'json'

CELERY_RESULT_SERIALIZER = 'json'

CELERY_TIMEZONE = TIME_ZONE

# Worker configuration
CELERY_WORKER_MAX_TASKS_PER_CHILD = 10

CELERY_WORKER_PREFETCH_MULTIPLIER = 1

CELERY_TASK_ALWAYS_EAGER = False

CELERY_TASK_EAGER_PROPAGATES = False

# Beat configuration
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

# Monitoring and health checks
CELERY_SEND_TASK_EVENTS = True

CELERY_TASK_TRACK_STARTED = True

CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutes

CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60  # 25 minutes


# Misago specific settings for production

# Use proper attachment server for production
MISAGO_ATTACHMENTS_SERVER = "misago.attachments.servers.django_redirect_response"

# Avatar sizes for production
MISAGO_AVATARS_SIZES = [400, 200, 100, 80, 60, 50]

# PostgreSQL text search configuration
MISAGO_SEARCH_CONFIG = "english"

# Paths for production
MISAGO_USER_DATA_DOWNLOADS_WORKING_DIR = os.path.join(BASE_DIR, "userdata")

MISAGO_AVATAR_GALLERY = os.path.join(BASE_DIR, "avatargallery")

# Profile fields
MISAGO_PROFILE_FIELDS = [
    {
        "name": "Personal",
        "fields": [
            "misago.users.profilefields.default.RealNameField",
            "misago.users.profilefields.default.GenderField",
            "misago.users.profilefields.default.BioField",
            "misago.users.profilefields.default.LocationField",
        ],
    },
    {
        "name": "Contact",
        "fields": [
            "misago.users.profilefields.default.TwitterHandleField",
            "misago.users.profilefields.default.SkypeIdField",
            "misago.users.profilefields.default.WebsiteField",
        ],
    },
    {
        "name": "IP address",
        "fields": ["misago.users.profilefields.default.JoinIpField"],
    },
]


# Performance optimization settings

# Data cache timeout
DATA_CACHE_TIMEOUT = 300

# Template cache timeout
TEMPLATE_CACHE_TIMEOUT = 300

# Database connection pooling
CONN_MAX_AGE = 60

# Static files optimization
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.ManifestStaticFilesStorage'

# Enable GZIP compression
MIDDLEWARE.insert(0, 'django.middleware.gzip.GZipMiddleware')

# Cache middleware
MIDDLEWARE.insert(0, 'django.middleware.cache.UpdateCacheMiddleware')
MIDDLEWARE.append('django.middleware.cache.FetchFromCacheMiddleware')


# Rate limiting
RATELIMIT_USE_CACHE = "default"

# File upload settings
FILE_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 5242880  # 5MB
FILE_UPLOAD_PERMISSIONS = 0o644
FILE_UPLOAD_DIRECTORY_PERMISSIONS = 0o755


# Health check endpoint
HEALTH_CHECK = {
    'DISK_USAGE_MAX': 90,  # percentage
    'MEMORY_MIN': 100,  # MB
}

# Sentry error monitoring (optional)
if config('SENTRY_DSN', default=None):
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration
    from sentry_sdk.integrations.celery import CeleryIntegration
    from sentry_sdk.integrations.redis import RedisIntegration
    
    sentry_sdk.init(
        dsn=config('SENTRY_DSN'),
        integrations=[
            DjangoIntegration(),
            CeleryIntegration(),
            RedisIntegration(),
        ],
        traces_sample_rate=0.1,
        send_default_pii=False,
        environment='production'
    )