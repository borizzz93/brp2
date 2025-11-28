from django.urls import path

from .views import healthcheck, readiness, liveness, metrics

urlpatterns = [
    path("health/", healthcheck, name="healthcheck"),
    path("ready/", readiness, name="readiness"),
    path("live/", liveness, name="liveness"),
    path("metrics/", metrics, name="metrics"),
]
