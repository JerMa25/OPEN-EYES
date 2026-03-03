# contacts/models.py

from django.db import models

class Contact(models.Model):
    """
    Modèle représentant un contact d'urgence
    """
    class TypeContact(models.TextChoices):
        FAMILLE = 'FAMILLE', 'Famille'
        AMI = 'AMI', 'Ami'
        SOIGNANT = 'SOIGNANT', 'Soignant'
        URGENCE = 'URGENCE', 'Service d\'urgence'
        AUTRE = 'AUTRE', 'Autre'
    
    canne = models.ForeignKey(
        'canes.Canne',
        on_delete=models.CASCADE,
        related_name='contacts'
    )
    nom = models.CharField(max_length=100)
    prenom = models.CharField(max_length=100, blank=True)
    telephone = models.CharField(max_length=20)
    type_contact = models.CharField(
        max_length=20,
        choices=TypeContact.choices,
        default=TypeContact.FAMILLE
    )
    priorite = models.IntegerField(
        default=1,
        help_text="1 = priorité maximale"
    )
    ajoute_par = models.ForeignKey(
        'users.User',
        on_delete=models.SET_NULL,
        null=True,
        related_name='contacts_ajoutes'
    )
    id_microcontroleur = models.IntegerField(
        null=True,
        blank=True,
        help_text="ID du contact dans la mémoire du microcontrôleur"
    )
    synchro_avec_canne = models.BooleanField(
        default=False,
        help_text="Contact synchronisé avec la canne"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Contact'
        verbose_name_plural = 'Contacts'
        ordering = ['priorite', 'nom']
        unique_together = [['canne', 'telephone']]
    
    def __str__(self):
        return f"{self.nom} {self.prenom} - {self.telephone}"
    
    def peut_etre_modifie_par(self, user):
        """Vérifie si l'utilisateur peut modifier ce contact"""
        return user.is_superadmin() or self.ajoute_par == user
    
    def peut_etre_supprime_par(self, user):
        """Seul le superadmin peut supprimer"""
        return user.is_superadmin()
