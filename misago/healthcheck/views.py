"""
Health check endpoints for Misago production deployment.
Provides monitoring and health status endpoints.
"""

from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache
import redis
import os
from django.conf import settings
from rest_framework.decorators import action

# Make psutil optional to prevent import errors
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


@action(methods=["get"], detail=True)
def healthcheck(request):
    """
    Main health check endpoint for load balancers and monitoring systems.
    Returns JSON response with service status.
    """
    try:
        # Check database connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        db_status = "ok"
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    # Check Redis connection
    try:
        cache.set("health_check", "ok", 10)
        result = cache.get("health_check")
        redis_status = "ok" if result == "ok" else "error"
    except Exception as e:
        redis_status = f"error: {str(e)}"
    
    # Check disk usage
    if PSUTIL_AVAILABLE:
        try:
            disk_usage = psutil.disk_usage('/')
            disk_status = "ok" if disk_usage.percent < 90 else "warning"
        except Exception as e:
            disk_status = f"error: {str(e)}"
    else:
        disk_status = "unknown (psutil not available)"
    
    # Check memory usage
    if PSUTIL_AVAILABLE:
        try:
            memory = psutil.virtual_memory()
            memory_status = "ok" if memory.percent < 90 else "warning"
        except Exception as e:
            memory_status = f"error: {str(e)}"
    else:
        memory_status = "unknown (psutil not available)"
    
    # Overall status
    overall_status = "ok"
    if db_status != "ok" or redis_status != "ok":
        overall_status = "error"
    elif disk_status == "warning" or memory_status == "warning":
        overall_status = "warning"
    
    # Prepare response
    response_data = {
        "status": overall_status,
        "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
        "service": "misago",
        "version": getattr(settings, 'MISAGO_VERSION', 'unknown'),
        "checks": {
            "database": db_status,
            "redis": redis_status,
            "disk": disk_status,
            "memory": memory_status,
        },
        "system": {}
    }
    
    # Add system metrics only if psutil is available
    if PSUTIL_AVAILABLE:
        try:
            response_data["system"] = {
                "cpu_percent": psutil.cpu_percent(interval=1),
                "memory_percent": memory.percent if 'memory' in locals() else 0,
                "disk_percent": disk_usage.percent if 'disk_usage' in locals() else 0,
            }
        except Exception as e:
            response_data["system"]["error"] = str(e)
    
    # Set appropriate HTTP status code
    status_code = 200
    if overall_status == "error":
        status_code = 503
    elif overall_status == "warning":
        status_code = 200
    
    return JsonResponse(response_data, status=status_code)


@action(methods=["get"], detail=True)
def readiness(request):
    """
    Kubernetes-style readiness probe.
    Checks if the application is ready to serve traffic.
    """
    try:
        # Test database
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        
        # Test Redis
        cache.get("ready_check")
        
        return JsonResponse({
            "status": "ready",
            "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
        })
    except Exception as e:
        return JsonResponse({
            "status": "not_ready",
            "error": str(e),
            "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
        }, status=503)


@action(methods=["get"], detail=True)
def liveness(request):
    """
    Kubernetes-style liveness probe.
    Checks if the application is alive and functioning.
    """
    # Basic liveness check - if this endpoint is reachable, app is alive
    return JsonResponse({
        "status": "alive",
        "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
    })


@action(methods=["get"], detail=True)
def metrics(request):
    """
    Prometheus-style metrics endpoint.
    Returns basic metrics about the application state.
    """
    try:
        # Get system metrics
        if PSUTIL_AVAILABLE:
            cpu_percent = psutil.cpu_percent(interval=0.1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
        else:
            cpu_percent = None
            memory = None
            disk = None
        
        # Get database stats
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    count(*) as total_connections,
                    sum(case when state = 'active' then 1 else 0 end) as active_connections
                FROM pg_stat_activity 
                WHERE datname = %s
            """, [settings.DATABASES['default']['NAME']])
            db_stats = cursor.fetchone()
        
        # Get Redis info
        try:
            from django_redis import get_redis_connection
            redis_conn = get_redis_connection("default")
            redis_info = redis_conn.info()
        except:
            redis_info = {}
        
        response_data = {
            "metrics": {
                "system": {},
                "database": {
                    "total_connections": db_stats[0] if db_stats else 0,
                    "active_connections": db_stats[1] if db_stats else 0,
                },
                "redis": {
                    "connected_clients": redis_info.get('connected_clients', 0),
                    "used_memory_mb": round(redis_info.get('used_memory', 0) / (1024*1024), 2),
                    "used_memory_peak_mb": round(redis_info.get('used_memory_peak', 0) / (1024*1024), 2),
                }
            },
            "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
        }
        
        # Add system metrics only if psutil is available
        if PSUTIL_AVAILABLE and cpu_percent is not None:
            response_data["metrics"]["system"] = {
                "cpu_usage_percent": cpu_percent,
                "memory_usage_percent": memory.percent,
                "memory_available_gb": round(memory.available / (1024**3), 2),
                "disk_usage_percent": disk.percent,
                "disk_free_gb": round(disk.free / (1024**3), 2),
            }
        elif not PSUTIL_AVAILABLE:
            response_data["metrics"]["system"]["error"] = "psutil not available"
        
        return JsonResponse(response_data)
        
    except Exception as e:
        return JsonResponse({
            "error": str(e),
            "timestamp": request.META.get('HTTP_X_REQUEST_ID', ''),
        }, status=500)
