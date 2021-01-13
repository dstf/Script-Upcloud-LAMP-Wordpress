#!/bin/bash

#Set up an non-privileged user and sudo
echo -n "Enter the username: "
read username
echo -n "Enter the password: "
read -s password
adduser "$username"
echo $username:$password | chpasswd
#echo "$password" | passwd "$username" --stdin


#Setup sudoers so wheel group can sudo
echo "### Modifying sudoers ..."
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

#Updates
apt update
apt upgrade

# Set hostname
HOSTNAME=$(hostname)
FQDN=$(hostname -f)
IPV4=$(hostname -I | cut -d ' ' -f 1)
IPV6=$(hostname -I | cut -d ' ' -f 2)
hostnamectl set-hostname $HOSTNAME
echo "${IPV4} ${FQDN} ${HOSTNAME} www.${HOSTNAME}" >> /etc/hosts
echo "${IPV6} ${FQDN} ${HOSTNAME} www.${HOSTNAME}" >> /etc/hosts

#Install apache
apt-get install apache2 -y
#Install utility
apt install curl lynx dnsutils net-tools bash-completion wget lsof nano

# Install Php
apt-get install -y php php-mysql
apt-get install php7.3 php-pear libapache2-mod-php7.3 php7.3-mysql -y php-gd php7.3-cli php7.3-common php7.3 libapache2-mod-php7.3 php7.3-mysql php-imagick php7.3-common php7.3-gd php7.3-imap php7.3-json php7.3-curl php7.3-zip php7.3-xml php7.3-mbstring php7.3-bz2 php7.3-intl php7.3-gmp php-net-smtp php-mail-mime php-net-idna2 mailutils

#Install/configure UFW
apt install -y ufw
ufw default allow outgoing
ufw default deny incoming
ufw allow ssh
ufw allow http
ufw allow https
systemctl enable ufw
systemctl start ufw

# restart apache
systemctl enable apache2
systemctl restart apache2

#Create a copy of the default Apache configuration file for your site:
WEBSITE=$(hostname)

cat <<END >/etc/apache2/sites-available/$WEBSITE.conf
<Directory /var/www/html/$WEBSITE/>
Require all granted
</Directory>
<VirtualHost *:80>
        ServerName $WEBSITE
        ServerAlias www.$WEBSITE
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/$WEBSITE/
       	ErrorLog ${APACHE_LOG_DIR}/error.log
	    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
END
a2enmod rewrite
ln /etc/apache2/sites-available/$WEBSITE.conf /etc/apache2/sites-enabled/$WEBSITE.conf 

#database login credentials from user input
apt install mariadb-server
read -p "Database Host: " dbhost
read -p "Database Name: " dbname
read -p "Database User: " dbuser
read -p "Database Password: " dbpass
echo

#Create new database
echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" |debconf-set-selections

mysql -uroot -p $DB_PASSWORD -e "create database $dbname"
mysql -uroot -p $DB_PASSWORD -e "CREATE USER '$dbuser' IDENTIFIED BY '$dbpass';"
mysql -uroot -p $DB_PASSWORD -e "GRANT ALL ON $dbname.* TO '$dbuser' IDENTIFIED BY '$dbpass';"

service mariadb restart


# Install wordpress
rm /var/www/html/index.html
cd /var/www/html/
wget http://wordpress.org/latest.tar.gz
tar -xvf latest.tar.gz
rm latest.tar.gz 
mv wordpress $WEBSITE
chown -R www-data:www-data /var/www/html/$WEBSITE/
cd /var/www/html/$WEBSITE/
mv wp-config-sample.php wp-config.php

# set database details with perl find and replace
	perl -pi -e "s/database_name_here/$dbname/g" wp-config.php
	perl -pi -e "s/username_here/$dbuser/g" wp-config.php
	perl -pi -e "s/password_here/$dbpass/g" wp-config.php

# set WP salts
	perl -i -pe'
	   BEGIN {
	     @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
	     push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
	     sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
	   }
	   s/put your unique phrase here/salt()/ge
	' wp-config.php


systemctl restart apache2
        echo "========================="
	echo "Installation is complete."
	echo "========================="
