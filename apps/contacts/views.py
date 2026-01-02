from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework import status
from .serializers import ContactSerializer
from .models import Contact
from drf_spectacular.utils import extend_schema
from django.shortcuts import get_object_or_404

# Assurez-vous d'importer vos modèles et tâches
from .models import Contact
from apps.canes.models import Canne  # CORRECTION: Import du bon modèle
from core.sms.tasks import task_envoyer_sms


class RegisterContactViaSMSAPIView(APIView):
    permission_classes = [AllowAny]
    serializer_class = ContactSerializer

    @transaction.atomic
    def post(self, request, canne_id, role, numero_contact):
        """
        Enregistre un contact après confirmation par l'app mobile.
        """
        nom_contact = request.data.get('nom', 'Sans nom')
        
        # 1. Vérifier la canne
        try:
            canne = Canne.objects.get(id=canne_id)
        except Canne.DoesNotExist:
            return Response({"detail": "Canne non trouvée."}, status=404)
        
        # 2. Vérifier si le contact existe déjà pour éviter l'IntegrityError
        if Contact.objects.filter(canne=canne, telephone=numero_contact).exists():
            return Response({"detail": "Ce contact existe déjà pour cette canne."}, status=400)

        # 3. Trouver un index libre
        indices_occupes = Contact.objects.filter(canne=canne).values_list('id_microcontroleur', flat=True)
        index_libre = next((i for i in range(1, 6) if i not in indices_occupes), None)
        
        if index_libre is None:
            return Response({"detail": "Mémoire de la canne pleine (5 max)."}, status=400)
        
        # 4. Création
        contact = Contact.objects.create(
            canne=canne,
            nom=nom_contact,
            telephone=numero_contact,
            type_contact=role.upper(),
            id_microcontroleur=index_libre,
            synchro_avec_canne=True # On suppose True car Flutter a confirmé
        )

        # 5. RETOUR INDISPENSABLE
        return Response({
            "id": contact.id,
            "index": index_libre,
            "message": "Contact enregistré avec succès en base de données."
        }, status=status.HTTP_201_CREATED)

    def get(self, request, canne_id):
        # Correction : utiliser le champ id_microcontroleur qui existe dans ton modèle
        contacts = Contact.objects.filter(canne_id=canne_id).order_by('id_microcontroleur') 
        serializer = ContactSerializer(contacts, many=True)
        return Response(serializer.data)
        
        """# 4. Commande SMS structurée
        commande_sms = f"CONF:{index_libre}:{role.upper()}:{numero_contact}"
        
        # Au lieu de task_envoyer_sms.delay(...) directement :
        transaction.on_commit(lambda: task_envoyer_sms.delay(
            canne_id=canne.id, 
            contenu=commande_sms,
            user_id=request.user.id if request.user.is_authenticated else None
        ))
        
        return Response({
            "contact_id": contact.id,
            "index_eeprom": index_libre,
            "commande_envoyee": commande_sms,
            "message": "Commande SMS envoyée avec succès."
        }, status=status.HTTP_201_CREATED)"""

class UpdateContactAPIView(APIView):
    permission_classes = [AllowAny]
    serializer_class = ContactSerializer

    @extend_schema(
        summary="Mise à jour d'un contact via son numéro",
        description="Identifie le contact par son téléphone actuel et applique les modifications (nouveau numéro, rôle, etc.)."
    )
    def put(self, request, canne_id, telephone, role):
        # 1. VERIFICATION DU ROLE : ADMIN ou SUPER_ADMIN requis
        if role not in ['ADMIN', 'SUPER_ADMIN']:
            return Response(
                {"error": "Autorisation refusée. Seul un ADMIN peut modifier un contact."}, 
                status=status.HTTP_403_FORBIDDEN
            )

        # 2. RECHERCHE DE L'INSTANCE PAR TÉLÉPHONE
        # On cherche le contact qui possède ce numéro précis pour cette canne précise
        contact_instance = get_object_or_404(
            Contact, 
            telephone=telephone, 
            canne_id=canne_id
        )

        # 3. MISE A JOUR DES PARAMÈTRES
        # partial=True permet de ne modifier que ce qui est envoyé (ex: juste le nouveau numéro)
        serializer = ContactSerializer(
            contact_instance, 
            data=request.data, 
            partial=True 
        )
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": "success",
                "message": f"Le contact {telephone} a été mis à jour.",
                "nouveaux_parametres": serializer.data
            }, status=status.HTTP_200_OK)
            
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class DeleteContactAPIView(APIView):
    permission_classes = [AllowAny]
    serializer_class = ContactSerializer # Indispensable pour Swagger

    @extend_schema(
        summary="Suppression d'un contact par SUPER_ADMIN",
        description="Vérifie le rôle, la canne et le contact avant suppression."
    )
    # AJOUT des arguments canne_id, contact_id et role ici :
    def post(self, request, canne_id, contact_id, role):
        
        # 1. VERIFICATION DU ROLE (via l'URL)
        if role != 'SUPER_ADMIN':
            return Response(
                {"error": "Autorisation refusée. Seul le SUPER_ADMIN peut supprimer."}, 
                status=status.HTTP_403_FORBIDDEN
            )

        # 2. RECHERCHE ET VALIDATION COHERENCE
        # On vérifie que le contact appartient bien à la canne spécifiée dans l'URL
        contact_instance = get_object_or_404(
            Contact, 
            id=contact_id, 
            canne_id=canne_id
        )

        # 3. UTILISATION DU SERIALIZER (Optionnel pour suppression, mais utile pour valider l'objet)
        # On peut serializer l'instance avant de la supprimer pour confirmer ce qu'on efface
        serializer = ContactSerializer(contact_instance)
        data_supprimee = serializer.data

        # 4. EXECUTION DE LA SUPPRESSION
        index_libere = contact_instance.id_microcontroleur
        contact_instance.delete()

        return Response({
            "status": "success",
            "message": f"Contact supprimé avec succès.",
            "details": data_supprimee,
            "index_libere": index_libere
        }, status=status.HTTP_200_OK)