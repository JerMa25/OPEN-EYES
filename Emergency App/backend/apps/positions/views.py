from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics
from django.db.models import Count, Avg, DecimalField
from django.db.models.functions import Cast, Round
from drf_spectacular.utils import extend_schema
from rest_framework.permissions import AllowAny
from django.shortcuts import get_object_or_404 

from apps.canes.cane import Canne 
from .PositionHistory import PositionHistory 
from .PositionSerializer import PositionSerializer, FrequentPlaceSerializer

class UpdatePositionView(generics.GenericAPIView):
    """
    Vue pour mettre à jour la position d'une canne.
    
    IMPORTANT: Utilise GenericAPIView au lieu de APIView
    pour que Swagger puisse détecter automatiquement le serializer.
    """
    permission_classes = [AllowAny]
    serializer_class = PositionSerializer
    
    def post(self, request, canne_id, lieu):
        """
        Crée ou met à jour la position d'une canne.
        
        Args:
            request: Requête HTTP avec latitude, longitude, lieu (optionnel), source
            canne_id: ID de la canne
        
        Returns:
            Position créée/mise à jour avec code 200
        """
        # Récupère la canne
        canne = get_object_or_404(Canne, id=canne_id)
        
        # Valide les données avec le serializer
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        # 2. Valider les données reçues (Lat, Long, Lieu)
        serializer = PositionSerializer(data=request.data)
        
        if serializer.is_valid():
            # 3. CRÉATION d'une nouvelle ligne (on n'utilise plus update_or_create)
            # On utilise .save() en passant la canne manuellement
           serializer.save(canne=canne)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
       
        
        

class FrequentPlacesView(APIView):
    permission_classes = [AllowAny]
    # Indispensable pour enlever l'erreur "unable to guess serializer"
    serializer_class = FrequentPlaceSerializer 

    @extend_schema(
        summary="Obtenir les lieux les plus fréquentés",
        responses={200: FrequentPlaceSerializer(many=True)}
    )
    def get(self, request, canne_id):
        canne = get_object_or_404(Canne, id=canne_id)
        
        # 1. On récupère le comptage de tous les lieux
        stats_lieux = PositionHistory.objects.filter(canne_id=canne_id)\
            .exclude(lieu__in=['', None])\
            .values('lieu')\
            .annotate(nombre_de_visites=Count('id'))\
            .order_by('-nombre_de_visites')

        if not stats_lieux:
            return Response([], status=200)

        # 2. On récupère la fréquence maximale
        max_frequence = stats_lieux[0]['nombre_de_visites']

        # 3. On filtre pour garder les lieux ayant la fréquence maximale
        lieux_frequents = [item for item in stats_lieux if item['nombre_de_visites'] == max_frequence]

        # 4. On passe les données au serializer avant de les envoyer
        serializer = FrequentPlaceSerializer(lieux_frequents, many=True)
        return Response(serializer.data, status=200)
class PositionHistoryView(APIView):
    serializer_class = PositionSerializer

    @extend_schema(summary="Historique des 100 dernières positions")
    def get(self, request, canne_id):
        positions = PositionHistory.objects.filter(canne_id=canne_id).order_by('-timestamp')[:100]
        serializer = PositionSerializer(positions, many=True)
        return Response(serializer.data)