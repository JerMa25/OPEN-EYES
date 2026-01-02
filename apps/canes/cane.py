from django.db import models


class Canne(models.Model):
    """
    Modèle minimaliste représentant une canne intelligente.
    Permet de gérer le numéro GSM et quelques métadonnées essentielles.
    """
    class Statut(models.TextChoices):
        ACTIVE = 'ACTIVE', 'Active'
        INACTIVE = 'INACTIVE', 'Inactive'
        MAINTENANCE = 'MAINTENANCE', 'En maintenance'
    
    numero_gsm = models.CharField(
        max_length=20, 
        unique=True, 
        help_text="Numéro du module GSM de la canne"
    )
    statut = models.CharField(
        max_length=20,
        choices=Statut.choices,
        default=Statut.ACTIVE
    )
    derniere_communication = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="Dernière communication avec la canne"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Canne'
        verbose_name_plural = 'Cannes'
    
    def __str__(self):
        return f"Canne {self.numero_gsm}"
    
    def est_active(self):
        return self.statut == self.Statut.ACTIVE
