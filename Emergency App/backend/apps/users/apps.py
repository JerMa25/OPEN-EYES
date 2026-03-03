# apps/Model/users/apps.py

from django.apps import AppConfig

class UsersConfig(AppConfig):
    # La configuration par défaut de la clé primaire (standard pour Django 4+)
    default_auto_field = 'django.db.models.BigAutoField'
    
    # Le chemin d'importation complet du module (celui que vous aviez dans INSTALLED_APPS)
    # Ceci est utilisé par Django pour trouver le module
    name = 'apps.users' 
    
    # Le LABEL de l'application. C'est le nom court et unique utilisé pour les références.
    # C'est ce qui manque à Django pour comprendre 'users.user'.
    label = 'users' 
    
    def ready(self):
        # Ceci est la méthode où vous pouvez importer des signaux ou effectuer des initialisations
        # spécifiques à l'application. Laissez-la vide si vous n'en avez pas besoin.
        pass