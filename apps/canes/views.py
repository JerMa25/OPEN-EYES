from rest_framework.views import APIView
from rest_framework.generics import GenericAPIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from django.shortcuts import get_object_or_404

from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes

from .models import Canne
from .serializers import CanneSerializer  # serializer minimal à créer


class RegisterCaneAPIView(APIView):
    permission_classes = [AllowAny]
    serializer_class = CanneSerializer

    @extend_schema(
        summary="Enregistrer une nouvelle canne",
        description="Crée une canne à partir de son numéro GSM. Rôle SUPER_ADMIN requis.",
        parameters=[
            OpenApiParameter(
                name="role",
                type=OpenApiTypes.STR,
                location=OpenApiParameter.PATH,
                description="Rôle utilisateur (SUPER_ADMIN requis)"
            )
        ],
        request=CanneSerializer,
        responses={201: OpenApiTypes.OBJECT}
    )
    def post(self, request, role):
        if role != 'SUPER_ADMIN':
            return Response({"error": "Action réservée au SUPER_ADMIN"}, status=403)

        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        gsm = serializer.validated_data["numero_gsm"]
        statut = serializer.validated_data.get("statut", "ACTIVE")

        if Canne.objects.filter(numero_gsm=gsm).exists():
            return Response({"error": "Cette canne existe déjà."}, status=400)

        canne = Canne.objects.create(numero_gsm=gsm, statut=statut)

        return Response({
            "status": "success",
            "message": f"Canne {gsm} enregistrée.",
            "id": canne.id
        }, status=status.HTTP_201_CREATED)


class DeleteCaneAPIView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(
        summary="Supprimer une canne via son GSM",
        description="Supprime la canne et toutes ses données associées.",
        parameters=[
            OpenApiParameter(
                name="numero_gsm",
                type=OpenApiTypes.STR,
                location=OpenApiParameter.PATH,
                description="Numéro GSM de la canne"
            ),
            OpenApiParameter(
                name="role",
                type=OpenApiTypes.STR,
                location=OpenApiParameter.PATH,
                description="Rôle utilisateur (SUPER_ADMIN requis)"
            )
        ],
        responses={200: OpenApiTypes.OBJECT}
    )
    def post(self, request, numero_gsm, role):
        if role != 'SUPER_ADMIN':
            return Response({"error": "Action réservée au SUPER_ADMIN"}, status=403)

        canne = get_object_or_404(Canne, numero_gsm=numero_gsm)
        canne.delete()

        return Response({
            "status": "success",
            "message": f"La canne {numero_gsm} a été supprimée."
        }, status=status.HTTP_200_OK)

# =============================================
# Vue pour lister toutes les cannes
# =============================================
class CaneListAPIView(APIView):
    """
    Liste toutes les cannes enregistrées.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary="Liste toutes les cannes",
        description="Retourne la liste complète des cannes enregistrées dans le système.",
        responses={200: CanneSerializer(many=True)}
    )
    def get(self, request, *args, **kwargs):
        queryset = Canne.objects.all().order_by('-id')
        serializer = CanneSerializer(queryset, many=True)
        return Response(serializer.data)
