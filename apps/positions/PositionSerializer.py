from rest_framework import serializers
from .PositionHistory import PositionHistory

class PositionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PositionHistory
        fields = ['canne_id', 'lieu']

class FrequentPlaceSerializer(serializers.Serializer):
    lieu = serializers.CharField()
    nombre_de_visites = serializers.IntegerField()