from django.db import models
from django.conf import settings
from apps.canes.models import Canne

class SMSLog(models.Model):
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'),
        ('ENVOYE', 'Envoyé'),
        ('ECHEC', 'Échec'),
    ]

    canne = models.ForeignKey(Canne, on_delete=models.CASCADE, related_name='sms_logs')
    contenu = models.TextField()
    telephone_destinataire = models.CharField(max_length=20)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='EN_ATTENTE')
    date_envoi = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True
    )
    erreur_details = models.TextField(null=True, blank=True)

    def __str__(self):
        return f"SMS vers {self.telephone_destinataire} - {self.statut}"