from django.urls import path
from .views import RegisterContactViaSMSAPIView, UpdateContactAPIView, DeleteContactAPIView

urlpatterns = [
    # Route : /api/contacts/register-sms/<id_canne>/
   path('register-sms/<int:canne_id>/<str:role>/<str:numero_contact>/', 
     RegisterContactViaSMSAPIView.as_view(), 
     name='register-sms'),
   path('<int:canne_id>/', RegisterContactViaSMSAPIView.as_view(), name='contacts-par-canne'),
   path('<int:canne_id>/contacts/<str:telephone>/<str:role>/update/', UpdateContactAPIView.as_view(), name='contact-update'),
   path('<int:canne_id>/contacts/<int:contact_id>/<str:role>/delete/', DeleteContactAPIView.as_view(), name='contact-delete'),
]