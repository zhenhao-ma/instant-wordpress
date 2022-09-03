#/bin/sh

#### Some critical information
printf "==========Welcome to 牛津小马哥 的脚本=========\n"
printf "|                                             |\n"
printf "|       Ubuntu20.04自动Wordpress搭建脚本      |\n"
printf "|                                             |\n"
printf "===============================================\n"
printf "请输入你的域名：\n"
read -p "" domain
sleep 1
printf "请输入你的邮箱：\n"
read -p "" email
sleep 1

install_dir="/var/www/html"
#### Creating Random WP Database Credenitals
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-12'`
sleep 1
mysqlrootpass=`date |md5sum |cut -c '1-12'`
sleep 1


#### Install Packages for https and mysql
apt -y update
apt -y upgrade
apt -y install apache2
apt -y install mysql-server


#### Start http
rm /var/www/html/index.html
systemctl enable apache2
systemctl start apache2

#### Start mysql and set root password

systemctl enable mysql
systemctl start mysql

/usr/bin/mysql -e "USE mysql;"
/usr/bin/mysql -e "UPDATE user SET Password=PASSWORD($mysqlrootpass) WHERE user='root';"
/usr/bin/mysql -e "FLUSH PRIVILEGES;"
touch /root/.my.cnf
chmod 640 /root/.my.cnf
echo "[client]">>/root/.my.cnf
echo "user=root">>/root/.my.cnf
echo "password="$mysqlrootpass>>/root/.my.cnf
####Install PHP
apt -y install php php-bz2 php-mysqli php-curl php-gd php-intl php-common php-mbstring php-xml

sed -i '0,/AllowOverride\ None/! {0,/AllowOverride\ None/ s/AllowOverride\ None/AllowOverride\ All/}' /etc/apache2/apache2.conf #Allow htaccess usage

systemctl restart apache2

####Download and extract latest WordPress Package
if test -f /tmp/latest.tar.gz
then
echo "WP is already downloaded."
else
echo "Downloading WordPress"
cd /tmp/ && wget "http://wordpress.org/latest.tar.gz";
fi

/bin/tar -C $install_dir -zxf /tmp/latest.tar.gz --strip-components=1
chown www-data: $install_dir -R

#### Create WP-config and set DB credentials
/bin/mv $install_dir/wp-config-sample.php $install_dir/wp-config.php

/bin/sed -i "s/database_name_here/$db_name/g" $install_dir/wp-config.php
/bin/sed -i "s/username_here/$db_user/g" $install_dir/wp-config.php
/bin/sed -i "s/password_here/$db_password/g" $install_dir/wp-config.php

cat << EOF >> $install_dir/wp-config.php
define('FS_METHOD', 'direct');
EOF

cat << EOF >> $install_dir/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index.php$ – [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

chown www-data: $install_dir -R

##### Set WP Salts
grep -A50 'table_prefix' $install_dir/wp-config.php > /tmp/wp-tmp-config
/bin/sed -i '/**#@/,/$p/d' $install_dir/wp-config.php
/usr/bin/lynx --dump -width 200 https://api.wordpress.org/secret-key/1.1/salt/ >> $install_dir/wp-config.php
/bin/cat /tmp/wp-tmp-config >> $install_dir/wp-config.php && rm /tmp/wp-tmp-config -f
/usr/bin/mysql -u root -e "CREATE DATABASE $db_name"
/usr/bin/mysql -u root -e "CREATE USER '$db_name'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_password';"
/usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"


##### Config Apache
echo "<VirtualHost *:80>
    ServerName ${domain}
    ServerAlias www.${domain}
    ServerAdmin webmaster@localhost
    DocumentRoot ${install_dir}
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    <Directory ${install_dir}>
	    AllowOverride All
    </Directory>
</VirtualHost>" > "/etc/apache2/sites-available/$domain.conf"

sudo a2ensite $domain
sudo a2dissite 000-default && sudo a2enmod rewrite && sudo a2enmod rewrite && sudo apache2ctl configtest && sudo systemctl restart apache2

##### Certbot for SSL
sudo apt install certbot python3-certbot-apache -y
sudo ufw allow 'Apache Full' && sudo ufw delete allow 'Apache'
sudo certbot --apache --non-interactive --no-eff-email --agree-tos --redirect -m $email --domain $domain --domain "www.$domain"

######Display generated passwords to log file.
printf "===============================================\n"
printf "|                                             |\n"
printf "|              牛津小马哥个人网站             |\n"
printf "|                 xmg180.com                  |\n"
printf "|       了解他，一起学跨境电商，学编程        |\n"
printf "|                                             |\n"
printf "===============================================\n"
echo "你的网站: " "https://${domain}"
echo "你的SSL绑定邮箱: " $email
echo "数据库名称 Db: " $db_name
echo "数据库用户名 User: " $db_user
echo "数据库密码 Password: " $db_password
echo "Mysql管理员密码 Root Password: " $mysqlrootpass
