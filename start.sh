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
