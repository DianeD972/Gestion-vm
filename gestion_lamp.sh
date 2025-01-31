#!/usr/bin/env bash
set -e

# ------------------------------------------------------------------------------
# Script d’installation/configuration LAMP (Apache, MariaDB, PHP) 
# - Installe MariaDB seulement si elle n’est pas déjà installée.
# - Sécurise MariaDB sans forcer une reconfiguration si le compte root
#   est déjà en plugin mysql_native_password ou autre.
# - Peut être relancé plusieurs fois sans déclencher d’erreurs de configuration.
# ------------------------------------------------------------------------------

# Mot de passe root si on doit basculer depuis unix_socket -> mysql_native_password
DB_ROOT_PASSWORD="MonSuperMotDePasse"

echo "=== Mise à jour du cache des paquets ==="
sudo apt-get update -y

# 1. Installation Apache (si absent)
if ! dpkg -l | grep -q "^ii  apache2 "; then
  echo "=== Installation d'Apache ==="
  sudo apt-get install -y apache2
  sudo systemctl enable apache2
  sudo systemctl start apache2
else
  echo "=== Apache déjà installé, on ne fait rien. ==="
fi

# 2. Installation MariaDB (si absent)
if ! dpkg -l | grep -q "^ii  mariadb-server "; then
  echo "=== Installation de MariaDB ==="
  sudo apt-get install -y mariadb-server mariadb-client
  sudo systemctl enable mariadb
  sudo systemctl start mariadb
else
  echo "=== MariaDB déjà installé, on ne fait rien. ==="
  # S'assurer juste que le service est lancé
  sudo systemctl enable mariadb || true
  sudo systemctl start mariadb || true
fi

# 3. Installation PHP (si absent)
#    - On installe aussi libapache2-mod-php et php-mysql si non présents
if ! dpkg -l | grep -q "^ii  php "; then
  echo "=== Installation de PHP + extensions ==="
  sudo apt-get install -y php libapache2-mod-php php-mysql
else
  echo "=== PHP déjà installé, on ne fait rien. ==="
fi

# ------------------------------------------------------------------------------
# Sécurisation de MariaDB (idempotente)
# ------------------------------------------------------------------------------
echo "=== Sécurisation MariaDB (suppression utilisateurs anonymes, base test, etc.) ==="

# Vérifier si le plugin root est encore "unix_socket" ou non.
#  - On n'agit que si le plugin=unix_socket. Sinon, on suppose que la config root est déjà faite.
CURRENT_PLUGIN=$(sudo mysql -sN -e "SELECT plugin FROM mysql.user WHERE user='root' AND host='localhost';" 2>/dev/null || echo "")

if [ "$CURRENT_PLUGIN" = "unix_socket" ]; then
  echo "  -> root est en unix_socket. On définit mysql_native_password + mot de passe root."
  sudo mysql <<EOF
    UPDATE mysql.user
       SET plugin = 'mysql_native_password'
     WHERE user = 'root' AND host='localhost';
    FLUSH PRIVILEGES;

    ALTER USER 'root'@'localhost'
       IDENTIFIED BY '${DB_ROOT_PASSWORD}';

    DELETE FROM mysql.user WHERE user = '';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
    FLUSH PRIVILEGES;
EOF

elif [ "$CURRENT_PLUGIN" = "mysql_native_password" ]; then
  echo "  -> root est déjà en mysql_native_password : on ne rechange pas son mot de passe."
  # On se connecte avec le mot de passe actuel (qu'on suppose être DB_ROOT_PASSWORD),
  #  pour supprimer utilisateurs anonymes et base test.
  #  Si le mot de passe root est différent, la commande échouera, mais le script n'est pas bloquant.
  sudo mysql -u root -p"${DB_ROOT_PASSWORD}" <<EOF || true
    DELETE FROM mysql.user WHERE user = '';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
    FLUSH PRIVILEGES;
EOF

else
  echo "  -> Plugin root actuel = '$CURRENT_PLUGIN'. Aucune action sur le plugin/mot de passe."
  echo "     (On nettoie juste la base test et les utilisateurs anonymes sans mot de passe.)"

  # Dans ce cas, on essaie quand même de supprimer base test & anonymes
  #  en utilisant 'sudo mysql' sans mot de passe (si plugin = unix_socket ou autre).
  sudo mysql <<EOF || true
    DELETE FROM mysql.user WHERE user = '';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
    FLUSH PRIVILEGES;
EOF
fi

echo "=== Sécurisation MariaDB terminée ==="

# ------------------------------------------------------------------------------
# Configuration basique Apache : activer mod_rewrite, si non déjà fait.
# ------------------------------------------------------------------------------
echo "=== Configuration Apache : activation mod_rewrite ==="
sudo a2enmod rewrite
sudo systemctl reload apache2

# ------------------------------------------------------------------------------
# Création d’un fichier de test PHP info.php (idempotent)
# ------------------------------------------------------------------------------
if [ ! -f /var/www/html/info.php ]; then
  echo "=== Création de /var/www/html/info.php ==="
  cat <<PHPINFO | sudo tee /var/www/html/info.php
<?php
  phpinfo();
?>
PHPINFO
else
  echo "=== Fichier info.php déjà présent, on ne fait rien. ==="
fi

# ------------------------------------------------------------------------------
# État final
# ------------------------------------------------------------------------------
echo "=== État des services ==="
systemctl status apache2 --no-pager || true
systemctl status mariadb --no-pager || true

echo "========================================"
echo "Installation / configuration LAMP terminée."
echo "Vous pouvez tester PHP : http://<IP_ou_nom>/info.php"
echo "========================================"
