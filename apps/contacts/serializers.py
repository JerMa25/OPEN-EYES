from rest_framework import serializers
from .models import Contact

class ContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = Contact
        # On exclut les champs gérés automatiquement ou par le système
        fields = [
            'id', 'canne', 'nom', 'prenom', 'telephone', 
            'type_contact', 'priorite', 'id_microcontroleur', 
            'synchro_avec_canne'
        ]
        read_only_fields = ['synchro_avec_canne', 'id_microcontroleur']

    def validate_telephone(self, value):
        # Vous pourriez ajouter ici une validation de format de numéro (ex: phonenumbers)
        return value