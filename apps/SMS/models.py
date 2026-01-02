from django.db import models
class SMS(models.Model):
    """
    Modèle pour l'historique des SMS échangés avec la canne
    """
    class TypeMessage(models.TextChoices):
        COMMANDE = 'COMMANDE', 'Commande envoyée'
        REPONSE = 'REPONSE', 'Réponse reçue'
    
    class StatutMessage(models.TextChoices):
        EN_ATTENTE = 'EN_ATTENTE', 'En attente'
        ENVOYE = 'ENVOYE', 'Envoyé'
        RECU = 'RECU', 'Reçu'
        ERREUR = 'ERREUR', 'Erreur'
    
    canne = models.ForeignKey(
        'canes.Canne',
        on_delete=models.CASCADE,
        related_name='messages'
    )
    type_message = models.CharField(
        max_length=20,
        choices=TypeMessage.choices
    )
    contenu = models.TextField()
    statut = models.CharField(
        max_length=20,
        choices=StatutMessage.choices,
        default=StatutMessage.EN_ATTENTE
    )
    envoye_par = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    timestamp = models.DateTimeField(auto_now_add=True)
    erreur_details = models.TextField(blank=True)
    
    class Meta:
        verbose_name = 'Message SMS'
        verbose_name_plural = 'Messages SMS'
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.get_type_message_display()} - {self.canne.numero_serie} - {self.timestamp}"