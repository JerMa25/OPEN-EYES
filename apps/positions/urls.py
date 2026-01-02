from django.urls import path
from .views import UpdatePositionView, FrequentPlacesView #PositionHistoryView # Ajout de PositionHistoryView ici

urlpatterns = [
    #path('<int:canne_id>/positions/historique/', PositionHistoryView.as_view(), name='position-historique'),
    path('<int:canne_id>/positions/frequents/', FrequentPlacesView.as_view(), name='position-frequents'),
    path('position-update/<int:canne_id>/<str:lieu>/positions/update/', UpdatePositionView.as_view(), name='position-update'),
]