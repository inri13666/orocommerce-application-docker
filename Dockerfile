FROM phusion/baseimage:18.04-1.0.0

MAINTAINER Nikita Makarov <mesaverde228@gmail.com>

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV HOME        /root
ENV SYMFONY_ENV prod

#Web Site Home
ENV HOME_SITE "/home/site/wwwroot"

RUN set -ex\
    && test ! -d ${HOME_SITE} && mkdir -p ${HOME_SITE} \
    && test ! -d /home/LogFiles && mkdir -p /home/LogFiles \
    && test ! -d /home/LogFiles/nginx && mkdir -p /home/LogFiles/nginx

RUN set -ex\
    && rm -rf /var/www \
    && test ! -d /var/www && mkdir -p /var/www \
	&& chown -R www-data:www-data /var/www \
	&& ln -s ${HOME_SITE} /var/www/wwwroot

# INITIAL
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
CMD ["/sbin/my_init"]

# PHP
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y \
        mc curl wget build-essential software-properties-common git subversion openssh-server acl \
        nodejs npm && \
    add-apt-repository -y ppa:ondrej/php && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --force-yes \
               php7.1-cli php7.1-fpm php7.1-curl php7.1-gd php7.1-mcrypt php7.1-intl php7.1-mbstring php7.1-xml php7.1-soap \
               php7.1-mysql php7.1-pgsql \
               php7.1-zip \
               nginx

COPY .build/sshd_config /etc/ssh/

# SSH
ENV SSH_PASSWD "root:Docker!"
RUN echo "$SSH_PASSWD" | chpasswd

RUN mkdir -p /run/php && touch /run/php/php7.1-fpm.sock && touch /run/php/php7.1-fpm.pid && chmod 777 /run/php/php7.1-fpm.sock
ADD .build/default.conf /etc/nginx/sites-available/default

#Logs
# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& ln -sf /dev/stderr /var/log/php7.1-fpm.log

#Configure PHP-FPM
RUN sed -i "s/curl.cainfo =.*/curl.cainfo = \/etc\/php\/7.1\/cacert.pem/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/memory_limit =.*/memory_limit = -1/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/upload_max_filesize =.*/upload_max_filesize = 50m/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/file_uploads =.*/file_uploads = On/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/post_max_size =.*/post_max_size = 50m/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/display_errors =.*/display_errors = Off/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/max_input_vars =.*/max_input_vars = 10000/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/max_input_time =.*/max_input_time = 900/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/max_execution_time =.*/max_input_time = 600/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/realpath_cache_ttl =.*/realpath_cache_ttl = 9120/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/realpath_cache_size =.*/realpath_cache_size = 16m/" /etc/php/7.1/fpm/php.ini && \
    sed -i "s/output_buffering =.*/output_buffering = 4096/" /etc/php/7.1/fpm/php.ini

#Configure PHP-CLI
RUN sed -i "s/curl.cainfo =.*/curl.cainfo = \/etc\/php\/7.1\/cacert.pem/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/memory_limit =.*/memory_limit = -1/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/cli_server.color =.*/cli_server.color = On/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/realpath_cache_ttl =.*/realpath_cache_ttl = 9120/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/realpath_cache_size =.*/realpath_cache_size = 16m/" /etc/php/7.1/cli/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/bin \
    --version=1.10.21 \
    --filename=composer \
    && mkdir /var/www/.composer \
    && chown www-data:www-data /var/www/.composer

ENV COMPOSER_HOME /var/www/.composer

USER www-data
RUN composer global require "fxp/composer-asset-plugin:~1.2" \
 && composer global require "hirak/prestissimo"
 
USER root
# Install PgSQL
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" >> /etc/apt/sources.list.d/postgresql.list && \
    apt-get update && apt-get install -y postgresql-9.6
	
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.6/main/pg_hba.conf
USER postgres
RUN /etc/init.d/postgresql start && sleep 10 &&\
    psql -c "ALTER USER postgres WITH PASSWORD '941202'" -d template1
 
USER root

# Install MySQL.
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /home/site/wwwroot

ARG APPLICATION_NAME=orocommerce-application
ARG APPLICATION_VERSION=1.6.36
ARG APPLICATION_URL=http://${APPLICATION_NAME}.example.com
ENV APPLICATION_DISTRIBUTIVE=${APPLICATION_NAME}-${APPLICATION_VERSION}.tar.bz2

#COPY .dist /home/site/wwwroot
RUN wget https://github.com/oroinc/${APPLICATION_NAME}/releases/download/${APPLICATION_VERSION}/${APPLICATION_DISTRIBUTIVE} && \
    tar -C /home/site/wwwroot --strip-components=1 -xjf ${APPLICATION_DISTRIBUTIVE} ${APPLICATION_NAME} && \
    rm -rf ${APPLICATION_DISTRIBUTIVE}

ADD .build/symfony-intl.patch /home/site/patches/symfony-intl.patch

# @see https://github.com/oroinc/platform/issues/912
RUN patch -s -p0 < /home/site/patches/symfony-intl.patch

RUN mkdir -p /var/run/mysqld && chown mysql:mysql -R /var/run/mysqld && /bin/bash -c "/usr/bin/mysqld_safe --skip-grant-tables &" && \
  sleep 5 && \
  ls -la /var/run/mysqld && \
  mysql -e "UPDATE mysql.user SET plugin='mysql_native_password'; FLUSH PRIVILEGES;" && \
  mysql -e "DROP DATABASE IF EXISTS oro_database;" && \
  mysql -e "CREATE DATABASE IF NOT EXISTS oro_database;" && \
  mysql -e "SHOW DATABASES" && \
  php -r "new PDO('mysql:hostname=127.0.0.1;dbname=oro_database', 'root');" || exit 13666 && \
  sed -i -e 's/database_driver: .*/database_driver: pdo_mysql /g' /home/site/wwwroot/app/config/parameters.yml && \
  sed -i -e 's/database_user: .*/database_user: root /g' /home/site/wwwroot/app/config/parameters.yml && \
  sed -i -e 's/database_password: .*/database_password: null /g' /home/site/wwwroot/app/config/parameters.yml && \
  sed -i -e 's/database_host: .*/database_host: 127.0.0.1 /g' /home/site/wwwroot/app/config/parameters.yml && \
  sed -i -e 's/database_name: .*/database_name: oro_database /g' /home/site/wwwroot/app/config/parameters.yml && \
  sed -i -e 's/installed: .*/installed: null /g' /home/site/wwwroot/app/config/parameters.yml && \
  php app/console oro:install \
     --application-url=${APPLICATION_URL}  \
     --organization-name="ORO" \
     --user-name=admin \
     --user-email=admin@example.com \
     --user-firstname=INRI \
     --user-lastname=SakiZ \
     --user-password=admin \
     --sample-data=y \
     --timeout=0 \
     --env=prod \
     -vvv && \
  mysqldump -u root oro_database > /home/site/database.mysql

# Clean UP
RUN set -ex && apt-get autoremove -y  && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /home/site/wwwroot/app/cache/de* /home/site/wwwroot/app/cache/pr*

# FINAL
COPY .build/app /usr/bin/app
COPY .build/init_container.sh /usr/local/bin/
RUN chmod +x /usr/bin/app
RUN chmod +x /usr/local/bin/init_container.sh
COPY .build/www.conf /etc/php/7.1/fpm/pool.d/www.conf
COPY .build/cacert.pem /etc/php/7.1/cacert.pem

# Expose all required ports
EXPOSE 8000 2222 3306

ENTRYPOINT ["init_container.sh"]
