# OPEN-EYES
Projet de canne intelligente pour les aveugles

**Emergency App** est une application mobile et serveur conçue pour assister les personnes malvoyantes en fournissant des fonctionnalités de localisation, de gestion de contacts d'urgence, et de communication via SMS. Le backend est développé en **Django REST Framework**, tandis que le frontend utilise **Flutter** pour couvrir Android, iOS et Web.

---

## 📁 Structure du projet

```
README.md
backend/               # API Django + Celery
  manage.py
  requirements.txt
  apps/                 # apps Django: canes, contacts, positions, SMS, users
  config/               # settings.py, urls, wsgi, celery
  core/                 # logique centrale (sms, services, tasks)
frontend/              # Application Flutter
  frontend/             # code principal
    lib/                # logiques Dart, model, pages, services
    android/ ios/ web/  # builds spécifiques
vue_aveugle/           # version accessible du frontend

# fichiers de support
docker-compose.yml
nginx.conf
deploy.sh
.env.example

``` 

---

## 🚀 Déploiement rapide (voir QUICKSTART.md)

1. Copier le template : `cp .env.example .env` et éditer les valeurs.
2. Lancer les services : `docker-compose up -d` ou `./deploy.sh dev setup`.
3. Appliquer les migrations et créer un superutilisateur.
4. Accéder à l'API sur `http://localhost:8000`, admin sur `/admin`.

Pour plus de détails, consultez :
- `QUICKSTART.md` (mise en route)
- `DEPLOYMENT_GUIDE.md` (guide complet)
- `CI-CD.md` (pipeline d'intégration continue)

---

## 🛠️ Technologies utilisées

- **Backend:** Python 3.10, Django 4.2, Django REST Framework, Celery, Redis, PostgreSQL
- **Authentification:** JWT personnalisé avec djangorestframework-simplejwt
- **Frontend:** Flutter 3.10, plugin bluetooth, géolocalisation, SMS, provider, dio
- **Infrastructure:** Docker, Docker Compose, Nginx, Gunicorn, Supervisor
- **CI/CD & DevOps:** GitHub Actions/GitLab CI, Docker Registry, Supervisor, Let's Encrypt

---

## 📦 Fonctionnalités principales

- Gestion des utilisateurs et contacts
- Suivi de position GPS (historique)
- Communication SMS via module GSM
- API REST sécurisée (JWT)
- Interface mobile responsive (Flutter)
- Tâches asynchrones pour lecture SMS et notifications
- Documentation automatique avec Swagger/OpenAPI

---

## 📋 Guides disponibles

Tous les guides sont inclus dans les fichiers Markdown suivant :
- **INDEX.md** : point d’entrée de la documentation
- **QUICKSTART.md** : démarrage local en quelques minutes
- **DEPLOYMENT_GUIDE.md** : instructions exhaustives de déploiement
- **CI-CD.md** : pipelines CI/CD prêts à l’emploi

---

## 🧩 Contribution

1. Forkez le repository.
2. Créez une branche pour votre fonctionnalité/bug fix.
3. Codez et ajoutez des tests.
4. Soumettez une Pull Request ou Merge Request.

Merci de respecter les conventions de style et de documenter vos modifications.

---

## 🪪 Licence

Ce projet est distribué sous la licence **MIT**. Voir le fichier `LICENSE.md` pour plus de détails.

---

## 📞 Contact

- Problèmes techniques : ouvre une issue sur GitHub/GitLab.
- Questions générales : Pour plus de questions, contactez aurorengadjou@gmail.com ou rtchapetngamini@gmail.com

---

**Dernière mise à jour :** Mars 2026

