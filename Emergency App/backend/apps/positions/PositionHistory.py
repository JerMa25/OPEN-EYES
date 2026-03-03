from django.db import models
from apps.canes.cane import Canne

class PositionHistory(models.Model):
    canne = models.ForeignKey(Canne, on_delete=models.CASCADE, related_name='positions')
    
   
    # Informations sur l'endroit
    lieu = models.CharField(max_length=255, blank=True, null=True)
    
    
    # Temps (Indispensable pour l'ordering)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = "Historique Position"

    def __str__(self):
        # Utilisation de f-string propre
        return f"Canne {self.canne_id} - {self.lieu or 'Lieu inconnu'} ({self.timestamp})"