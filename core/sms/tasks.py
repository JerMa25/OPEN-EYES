from celery import shared_task
import logging
from django.contrib.auth import get_user_model
from django.conf import settings

# --- IMPORTS CORRIGÉS ---
from core.sms.services import GSMHardwareService
from apps.canes.models import Canne 
from core.sms.models import SMSLog  # Import nécessaire pour créer le log
# ------------------------

logger = logging.getLogger('core.sms.urls')
User = get_user_model()

@shared_task(bind=True, max_retries=3)
def task_envoyer_sms(self, canne_id: int, contenu: str, user_id: int = None):
    try:
        from apps.canes.models import Canne
        canne = Canne.objects.get(id=canne_id)
        
        # On utilise le champ exact de ton modèle
        numero_destination = canne.numero_gsm 

        logger.info(f"Tentative d'envoi SMS vers {numero_destination}...")

        # Appel du service matériel
        success = GSMHardwareService.envoyer_sms_physique(
            numero=numero_destination, 
            message=contenu
        )
        
        if success:
            logger.info(f"Succès : Commande envoyée à la Canne {canne_id}")
            return {'status': 'success'}
        else:
            raise Exception("Le service GSM a échoué.")

    except Canne.DoesNotExist:
        logger.error(f"Canne {canne_id} introuvable.")
        return {'status': 'failed', 'reason': 'not_found'}
    except Exception as e:
        logger.error(f"Erreur : {str(e)}")
        # Relance la tâche dans 60 secondes
        raise self.retry(exc=e, countdown=60)

@shared_task
def task_lire_sms_recus():
    """
    Tâche planifiée pour interroger le module GSM et lire les réponses de la canne.
    """
    logger.info("Début du cycle de lecture des SMS entrants.")
    try:
        # Le service doit aussi être mis à jour pour cette méthode
        messages_traites = GSMHardwareService.lire_sms_recus()
        return f"Traitement terminé. {messages_traites} messages traités."
    except Exception as e:
        logger.error(f"Erreur lors de la lecture: {str(e)}")
        return f"Erreur: {str(e)}"