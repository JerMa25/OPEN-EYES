from django.urls import path
from .views import RegisterCaneAPIView, DeleteCaneAPIView, CaneListAPIView

urlpatterns = [
    # Enregistrement : POST /api/canes/register/SUPER_ADMIN/
    path('register/<str:role>/', RegisterCaneAPIView.as_view(), name='cane-register'),

    # Suppression : POST /api/canes/delete/+237699999999/SUPER_ADMIN/
    path('delete/<str:numero_gsm>/<str:role>/', DeleteCaneAPIView.as_view(), name='cane-delete'),
    path('list/', CaneListAPIView.as_view(), name='cane-list'),  # <-- nouveau endpoint
]