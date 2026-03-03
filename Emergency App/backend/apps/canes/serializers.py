from rest_framework import serializers
from .models import Canne

class CanneSerializer(serializers.ModelSerializer):
    # Champs calculés ou en lecture seule pour la sécurité
    est_active = serializers.BooleanField(read_only=True)
    created_at = serializers.DateTimeField(format="%d-%m-%Y %H:%M:%S", read_only=True)
    derniere_communication = serializers.DateTimeField(format="%d-%m-%Y %H:%M:%S", read_only=True)

    class Meta:
        model = Canne
        fields = [
            'id', 
            'numero_gsm', 
            'statut', 
            'derniere_communication', 
            'est_active', 
            'created_at', 
            'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'derniere_communication']

    def validate_numero_gsm(self, value):
        """
        Validation personnalisée pour s'assurer que le numéro 
        ressemble à un numéro de téléphone valide.
        """
        # Supprime les espaces éventuels
        numero = value.replace(" ", "")
        
        if not numero.replace("+", "").isdigit():
            raise serializers.ValidationError("Le numéro GSM ne doit contenir que des chiffres et éventuellement un '+'.")
        
        if len(numero) < 8:
            raise serializers.ValidationError("Le numéro GSM est trop court.")
            
        return numero