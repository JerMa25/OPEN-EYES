"""
Initialisation du package config
"""
# Importer Celery pour que Django le charge au démarrage
from .celery import app as celery_app

__all__ = ('celery_app',)