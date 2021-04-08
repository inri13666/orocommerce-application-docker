#!/bin/bash

# set -e

# Get environment variables to show up in SSH session
#eval $(printenv | awk -F= '{print "export " $1"="$2 }' >> /etc/profile)

# Get environment variables to show up in PHP-FPM session
eval $(echo "[www]" > /etc/php/${PHP_VERSION}/fpm/pool.d/env.conf)
eval $(env | sed "s/\(.*\)=\(.*\)/env[\1]='\2'/" >> /etc/php/${PHP_VERSION}/fpm/pool.d/env.conf)

export SYMFONY_ENV=prod

# setup server root
test ! -d "$HOME_SITE" && echo "INFO: $HOME_SITE not found. creating..." && mkdir -p "$HOME_SITE"
#if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then
#    echo "INFO: NOT in Azure, chown for "$HOME_SITE
#    chown -R www-data:www-data /home/site/wwwroot/app /home/site/wwwroot/web
#    HTTPDUSER=`ps aux | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1`
#    setfacl -R -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX "/home/site/wwwroot/app" "/home/site/wwwroot/web"
#    setfacl -dR -m u:"$HTTPDUSER":rwX -m u:`whoami`:rwX "/home/site/wwwroot/app" "/home/site/wwwroot/web"
#fi

# setup nginx log dir
# http://nginx.org/en/docs/ngx_core_module.html#error_log
# sed -i "s|error_log /var/log/error.log;|error_log stderr;|g" /etc/nginx/nginx.conf

#echo "Restoring Mysql database ..."
#  rm -rf /var/lib/ibdata1 && \
#  rm -rf /var/lib/ib_logfile0 && \
#  rm -rf /var/lib/ib_logfile1 && \
#  chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
#  service mysql start && \
#  mysql -u root -e 'DROP DATABASE IF EXISTS oro_database;' && \
#  mysql -u root -e 'CREATE DATABASE IF NOT EXISTS oro_database;' && \
#  mysql -u root oro_database < /home/site/database.mysql && \
#  service mysql start && \

#ls -la /var/log/supervisor && cat /etc/supervisor/supervisord.conf

#ln -sf /dev/stdout /var/log/supervisor/sshd.log
#ln -sf /dev/stderr /var/log/supervisor/sshd-errors.log
#ln -sf /dev/stdout /var/log/supervisor/mysql.log
#ln -sf /dev/stderr /var/log/supervisor/mysql-errors.log
#ln -sf /dev/stdout /var/log/supervisor/nginx.log
#ln -sf /dev/stderr /var/log/supervisor/nginx-errors.log

sed -i "s|loglevel=.*|loglevel=${SUPERVISOR_LOG_LEVEL:-warn}|" /etc/supervisor/conf.d/00-supervisord.conf
#rm -rf /var/log/supervisor
#ln -s /home/LogFiles/supervisor /var/log/supervisor
#ln -s /home/LogFiles/supervisor /var/log/supervisor

#echo "Starting consumer"
#rm -rf /home/site/wwwroot/app/cache/pr* && \
#rm -rf /home/site/wwwroot/app/cache/de* && \
#sudo -u www-data app oro:message-queue:consume -vvv --env=prod 1> /dev/stdout 2>/dev/stderr

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf && cat /var/log/supervisor/supervisord.log
