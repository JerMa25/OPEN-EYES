from django.urls import path
from .views import SMSHistoryListView

urlpatterns = [
    # GET /api/sms/canes/{canne_id}/history/
    path(
        'canes/<int:canne_id>/history/', 
        SMSHistoryListView.as_view(), 
        name='sms-history-list'
    ),
    # Vous inclurez cette URL dans votre fichier config/urls.py :
    # path('api/sms/', include('core.sms.urls')),
]