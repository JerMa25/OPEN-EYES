# app/users/user.py
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """
    Modèle utilisateur personnalisé avec gestion des rôles
    """
    class Role(models.TextChoices):
        SUPERADMIN = 'SUPERADMIN', 'Super Administrateur'
        ADMIN = 'ADMIN', 'Administrateur'
        CONTACT_TIERS = 'CONTACT_TIERS', 'Contact Tiers'
    
    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.ADMIN
    )
    telephone = models.CharField(max_length=20, unique=True)
    canne_associee = models.ForeignKey(
        'canes.Canne',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='administrateurs'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Utilisateur'
        verbose_name_plural = 'Utilisateurs'
    
    def __str__(self):
        return f"{self.get_full_name()} ({self.get_role_display()})"
    
    def is_superadmin(self):
        return self.role == self.Role.SUPERADMIN
    
    def is_admin(self):
        return self.role in [self.Role.SUPERADMIN, self.Role.ADMIN]
    
    def can_delete_contact(self):
        """Seul le superadmin peut supprimer des contacts"""
        return self.is_superadmin()
    
    def can_modify_role(self):
        """Seul le superadmin peut modifier les rôles"""
        return self.is_superadmin()
