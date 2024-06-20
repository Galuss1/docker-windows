# Environnement Docker

## Introduction
Après avoir configuré WSL2 et Docker Desktop, il est important de comprendre comment utiliser efficacement cet environnement pour le développement. Ce guide se concentre sur l'utilisation des fichiers Dockerfile, docker-compose.yml et d'un script de démarrage start.sh.

## Prérequis
- Docker Desktop doit être lancer (la distribution WSL2 (Ubuntu) doit être démarrer en premier, ensuite Docker Desktop)
- Les fichiers Docker (Dockerfile, docker-compose.yml, etc) doivent être présents à la racine du projet

## Présentation

### Fichier Dockerfile
Le fichier "Dockerfile" est un script de configuration utilisé pour automatiser le processus de création d'une image Docker. Il contient une série d'instructions pour installer des logiciels, copier des fichiers, et configurer des paramètres.
```bash
# Image Node.js officielle
FROM node:18

# Installation système (Apache : serveur web, curl+netcat-openbsd : utilisés dans le script de démarrage)
RUN apt-get update && apt-get install -y apache2 curl netcat-openbsd && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configuration Apache pour servir l'application React depuis /var/www/html/app/public
RUN echo '<Directory /var/www/html/app/public>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' > /etc/apache2/sites-available/000-default.conf

# Définir le répertoire de travail dans le dossier app, copier les fichiers package*.json et installer les dépendances npm
WORKDIR /var/www/html/app
COPY app/package*.json ./
RUN npm ci

# Retourner dans le répertoire de travail principal et copier le reste du contenu du projet, en respectant .dockerignore
WORKDIR /var/www/html
COPY . /var/www/html

# Permission pour exécuter le script de démarrage
RUN chmod +x /var/www/html/start.sh

# Exécuter le script de démarrage
CMD ["sh", "/var/www/html/start.sh"]

# L'utilisation d'un utilisateur non-root pour lancer le conteneur est recommandée
# Impossible d'utiliser un utilisateur non-root dans le contexte actuel car cela provoque des problèmes de permissions npm
# Les lignes suivantes sont donc commentées

# Permissions pour l'utilisateur 'node' sur tout le projet
# RUN chown -R node:node /var/www/html/ && \
#     chmod -R u+w /var/www/html/

# Utilisateur 'node'
# USER node
```

### Fichier docker-compose.yml
Le fichier docker-compose.yml est utilisé pour définir et exécuter des applications multi-conteneurs avec Docker. Il permet de configurer les services, les volumes, les réseaux, etc.\
Dans notre cas ce fichier permet également d'initialiser la base de données présente dans le fichier "init-db.sql".
```yml
version: '3.8'
services:
  app:
    container_name: react-app # Nom du conteneur
    build:
      context: . # Dossier de build (le dossier courant dans notre cas)
      dockerfile: Dockerfile # Fichier de build (Dockerfile dans notre cas, on pourrait aussi utiliser Dockerfile.dev pour un environnement de développement)
    ports:
      - 3000:3000 # Port d'écoute de l'application React (3000:3000 par défaut)
    volumes:
      - .:/var/www/html # Volume pour tout le projet
      - /var/www/html/app/node_modules # Volume pour les modules node_modules (pour éviter de les installer dans le conteneur)
    env_file:
      - .env # Utilisation du fichier .env pour les variables d'environnement
    depends_on:
      - database # Dépendance au conteneur de la base de données
      - mailhog # Dépendance au conteneur de MailHog
    #user: node # Utilisateur node pour le conteneur de l'application React (non utilisé dans notre cas, problème de permissions npm)

  database:
    container_name: database # Nom du conteneur
    image: mysql:5.7
    volumes:
      - database_data:/var/lib/mysql # Volume pour les données de MySQL
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql # Script SQL d'initialisation de la base de données depuis le fichier init-db.sql
    ports:
      - 3310:3306 # Port d'écoute de MySQL (3310:3306 pour éviter les conflits avec une éventuelle installation locale de MySQL -> 3306:3306 par défaut)
    env_file:
      - .env # Utilisation du fichier .env pour les variables d'environnement

  mailhog:
    container_name: mailhog # Nom du conteneur
    image: mailhog/mailhog # Image Docker de MailHog
    ports:
      - 8025:8025 # Port d'écoute de MailHog (8025:8025 par défaut)

volumes:
  database_data: {} # Volume pour les données de MySQL
```

### Fichier start.sh
Le script start.sh est utilisé pour initialiser et démarrer l'environnement de développement.\
Note : Le nom de ce script est personnalisable, il suffit juste de l'appeller correctement depuis le fichier Dockerfile.
```bash
# Démarrer Apache en arrière-plan
apache2-foreground &

# Laisser le temps à Apache de démarrer
sleep 5

# Attendre le démarrage de MySQL
until nc -z -v -w30 database 3306
do
  echo "start.sh : Waiting for MySQL to start to continue"
  sleep 5
done

# Log un message pour indiquer le démarrage de MySQL
echo "start.sh : MySQL started"

# Changer de répertoire vers /var/www/html/app
cd /var/www/html/app

# Démarrer l'application React avec npm start
npm start &

# Vérifier que l'application React est démarrée
until curl -s http://localhost:3000
do
  echo "start.sh : Waiting for the application to start to continue"
  sleep 5
done

# Log un message pour indiquer le démarrage de l'application
echo "start.sh : Application started"

# Log un message pour indiquer la fin du script
echo "start.sh : End of script execution, container ready"

# Maintenir le conteneur actif
tail -f /dev/null
```

## Utilisation
Pour construire l'image Docker, éxécuter la commande ci-dessous depuis la racine du projet contenant les fichiers Docker.
```bash
docker-compose up --build
```
L'image Docker va alors être installer grâce aux fichiers "Dockerfile" et "docker-compose.yml" puis le conteneur sera initialisé grâce au fichier "start.sh".
![](img/Screenshot_8.png)

Une fois l'installation terminé :
- L'application est accessible depuis http://localhost:3000
- La base de données est accessible depuis localhost:3310
- Un "service mailer" (mailhog) est également mis en place et accessible depuis http://localhost:8025/

Vous pouvez ensuite utiliser les commandes ci-dessous pour démarrer/arrêter les conteneurs sans lancer de build.
```bash
docker-compose up
```
```bash
docker-compose down
```

Les conteneurs, images, volumes sont également accessibles depuis Docker Desktop.\
Depuis les conteneurs vous pourrez accéder aux terminaux, logs, fichiers, etc.\
![](img/Screenshot_9.png)

## Libérer de l'espace
L'environnement Docker peux rapidement devenir encombrant, surtout si vous avez plusieurs images/projets.\
Vous pouvez supprimer les conteneurs, images et volumes directement depuis Docker Desktop, vous pouvez également utiliser les commandes ci-dessous.\
<br>
Supprimer les images non utilisées
```bash
docker image prune
```
Supprimer les conteneurs inactifs
```bash
docker container prune
```
Supprimer les volumes non utilisés
```bash
docker volume prune
```
Nettoyage global
```bash
docker system prune -a
```
Nettoyer le cache du builder
```bash
docker builder prune
```

## Autres commandes utiles
Utiliser le flag "-d" afin d'éxécuter les commandes en "fond" et maintenir le terminal utilisable
```bash
docker-compose up -d
docker-compose up --build -d
```
Lancer un build sans cache 
```bash
docker-compose build --no-cache
```
Exécuter un conteneur
```bash
docker run -p 3000:3000 <container_name>
```
Arrêter un conteneur
```bash
docker stop <container_id>
```
Lister les conteneurs
```bash
docker ps
```
Supprimer un conteneur
```bash
docker rm <container_id>
```
Supprimer une image
```bash
docker rmi <image_name>
```
Nettoyer le terminal
```bash
clear
```

## Axes d'amélioration
Bien que notre configuration Docker actuelle fonctionne correctement, certains aspects pourraient être améliorés pour optimiser l'efficacité :
- Apache avec Node.js/React : L'utilisation d'Apache n'est pas l'idéal pour un projet Node.js/React. Conçu principalement pour des applications PHP, Apache ne profite pas pleinement des caractéristiques de Node.js, ce qui pourrait limiter les performances de notre application.
- Image Node-Alpine : Nous pourrions bénéficier de l'utilisation de l'image Node-Alpine. Plus légère et compacte, cette image améliore les performances et accélère le déploiement de nos conteneurs, offrant ainsi une solution plus efficiente.
- Exécution du conteneur en tant qu'utilisateur non-root : Pour des raisons de sécurité, il est préférable d'exécuter les conteneurs en tant qu'utilisateur non-root. Cependant, dans notre configuration actuelle, cela entraîne des problèmes de permissions avec npm, nous forçant à utiliser l'utilisateur root.

## Astuces
- Forcer l'arrêt du conteneur depuis le terminal Ubuntu : Ctrl+Shift+C
- Coller depuis le terminal Ubuntu : Clic droit
- Coller depuis le terminal conteneur Docker App : Ctrl+Shift+V
- Récupérer les commandes précédente dans le terminal Ubuntu : Flèche directionnel haut

## Conclusion
L'utilisation efficace de Docker avec WSL2 peut considérablement améliorer votre workflow de développement. En comprenant et en utilisant correctement les fichiers Dockerfile, docker-compose.yml et start.sh, vous pouvez créer un environnement de développement robuste, répétable et portable.
