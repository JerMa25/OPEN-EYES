from rest_framework import serializers
from apps.SMS.models import SMS

class SMSSerializer(serializers.ModelSerializer):
    type_message_display = serializers.CharField(source='get_type_message_display', read_only=True)
    statut_display = serializers.CharField(source='get_statut_display', read_only=True)
    
    # On utilise un SerializerMethodField pour gérer le cas où l'utilisateur est absent
    envoye_par_nom = serializers.SerializerMethodField()

    class Meta:
        model = SMS
        fields = [
            'id', 
            'canne', 
            'type_message', 
            'type_message_display',
            'contenu', 
            'statut', 
            'statut_display',
            'envoye_par', 
            'envoye_par_nom',
            'timestamp', 
            'erreur_details'
        ]
        read_only_fields = fields

    def get_envoye_par_nom(self, obj):
        # On vérifie si l'objet envoye_par existe avant d'accéder à son username
        if obj.envoye_par:
            return obj.envoye_par.username
        return None