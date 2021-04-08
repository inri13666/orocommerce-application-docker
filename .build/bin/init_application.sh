#!/usr/bin/env bash

echo "Restoring Mysql database ..."
rm -rf /var/lib/ibdata1 &&
  rm -rf /var/lib/ib_logfile0 &&
  rm -rf /var/lib/ib_logfile1 &&
  service mysql start &&
  mysql -u root -e 'DROP DATABASE IF EXISTS oro_database;' &&
  mysql -u root -e 'CREATE DATABASE IF NOT EXISTS oro_database;' &&
  mysql -u root oro_database </home/site/database.mysql &&
  service mysql stop

#mkdir -p /run/php && touch /run/php/php7-fpm.sock && chmod -R www-data:www-data /run/php

supervisorctl restart mysql
supervisorctl restart php-fpm
supervisorctl restart consumer
supervisorctl restart nginx
