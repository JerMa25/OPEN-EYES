from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

urlpatterns = [
    path('admin/', admin.site.urls),
    # SMS API routes
    path('api/sms/', include('core.sms.urls')),
    path('api/contacts/', include('apps.contacts.urls')),
    path('api/positions/', include('apps.positions.urls')),
    path('api/canes/', include('apps.canes.urls')),
    # Add other app includes as needed:
    # path('api/contacts/', include('apps.Model.contacts.urls'))
    # Documentation API
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]
