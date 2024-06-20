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
