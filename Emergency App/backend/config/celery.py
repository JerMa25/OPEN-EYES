"""
Configuration Celery pour Smart Cane Backend
"""
import os
from celery import Celery
from django.conf import settings

# Définir le module de settings Django par défaut
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Créer l'instance Celery
app = Celery('smart_cane')

# Charger la configuration depuis Django settings avec le préfixe CELERY_
app.config_from_object('django.conf:settings', namespace='CELERY')

# IMPORTANT: Pour le développement, forcer le mode synchrone
# Cela évite les erreurs de connexion Redis/RabbitMQ
if settings.DEBUG:
    app.conf.update(
        task_always_eager=True,
        task_eager_propagates=True,
    )

# Auto-découverte des tâches dans les applications Django
app.autodiscover_tasks()


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Tâche de débogage pour tester Celery"""
    print(f'Request: {self.request!r}')