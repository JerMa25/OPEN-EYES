from rest_framework.generics import GenericAPIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny

from apps.SMS.models import SMS
from core.sms.serializers import SMSSerializer


class SMSHistoryListView(GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = SMSSerializer  # ✅ CORRECTION ICI

    def get_queryset(self):
        canne_id = self.kwargs.get("canne_id")
        return SMS.objects.filter(
            canne__numero_gsm=canne_id
        ).order_by("-timestamp")

    def get(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
