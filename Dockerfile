FROM ubuntu:18.04

MAINTAINER Nikita Makarov <mesaverde228@gmail.com>

ARG PHP_VERSION=7.1
ARG BD_ENGINE=mysql
ARG PGPASSWORD=941202
ARG APPLICATION_NAME=orocommerce-application
ARG APPLICATION_VERSION=1.6.39
ARG APPLICATION_URL=http://${APPLICATION_NAME}.example.com
ARG SYMFONY_ENV=prod

ENV APPLICATION_DISTRIBUTIVE=${APPLICATION_NAME}-${APPLICATION_VERSION}.tar.bz2
ENV PHP_VERSION=${PHP_VERSION}
ENV PGPASSWORD=${PGPASSWORD}
#Web Site Home
ENV HOME_SITE "/home/site/wwwroot"
ENV SYMFONY_ENV=${SYMFONY_ENV}
# Locale UTF-8
ENV LANG        en_US.UTF-8
ENV LC_ALL      en_US.UTF-8

# Setup PHP
RUN set -ex &&\
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y \
        mc curl wget software-properties-common openssh-server \
        nodejs npm \
        sudo \
        locales \
        && \
    locale-gen ${LANG} && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" >> /etc/apt/sources.list.d/postgresql.list && \
    add-apt-repository -y ppa:ondrej/php && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mcrypt \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-zip \
        nginx \
        supervisor \
        mysql-server-5.7 \
        postgresql-9.6 && \
    apt-get autoremove -y  && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

RUN set -ex && \
# Initial MySQL configuration
    mkdir -p /var/run/mysqld && \
    chown mysql:mysql -R /var/run/mysqld && \
    /bin/bash -c "/usr/bin/mysqld_safe --skip-grant-tables &" && \
    sleep 5 && \
    mysql -e "UPDATE mysql.user SET plugin='mysql_native_password'; FLUSH PRIVILEGES;" && \
    mysql -e "DROP DATABASE IF EXISTS oro_database;" && \
    mysql -e "CREATE DATABASE IF NOT EXISTS oro_database;" && \
    mysql -e "SHOW DATABASES" && \
    update-rc.d mysql disable && \
# Initial PostSQL configuration
    echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.6/main/pg_hba.conf && \
#Configure PHP-FPM
    sed -i "s/curl.cainfo =.*/curl.cainfo = \/etc\/php\/${PHP_VERSION}\/cacert.pem/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/memory_limit =.*/memory_limit = -1/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/upload_max_filesize =.*/upload_max_filesize = 50m/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/file_uploads =.*/file_uploads = On/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/post_max_size =.*/post_max_size = 50m/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/display_errors =.*/display_errors = Off/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/max_input_vars =.*/max_input_vars = 10000/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/max_input_time =.*/max_input_time = 900/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/max_execution_time =.*/max_input_time = 600/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/realpath_cache_ttl =.*/realpath_cache_ttl = 9120/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/realpath_cache_size =.*/realpath_cache_size = 16m/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
    sed -i "s/output_buffering =.*/output_buffering = 4096/" /etc/php/${PHP_VERSION}/fpm/php.ini && \
#Configure PHP-CLI
    sed -i "s/curl.cainfo =.*/curl.cainfo = \/etc\/php\/7.1\/cacert.pem/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/memory_limit =.*/memory_limit = -1/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/cli_server.color =.*/cli_server.color = On/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/realpath_cache_ttl =.*/realpath_cache_ttl = 9120/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/realpath_cache_size =.*/realpath_cache_size = 16m/" /etc/php/${PHP_VERSION}/cli/php.ini && \
    sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/${PHP_VERSION}/fpm/php.ini

USER postgres
RUN /etc/init.d/postgresql start && sleep 10 &&\
    psql -c "ALTER USER postgres WITH PASSWORD '${PGPASSWORD}'" -d template1

USER root
# Configure default WWW Root
RUN set -ex && \
    rm -rf /var/www && \
    test ! -d /var/www && mkdir -p /var/www && \
	chown -R www-data:www-data /var/www && \
	test ! -d ${HOME_SITE} && mkdir -p ${HOME_SITE} && \
    chown -R www-data:www-data ${HOME_SITE} && \
	ln -s ${HOME_SITE} /var/www/wwwroot

#ENV COMPOSER_HOME /var/www/.composer
## Composer
#RUN curl -sS https://getcomposer.org/installer | php -- \
#    --install-dir=/usr/bin \
#    --version=1.10.21 \
#    --filename=composer && \
#    mkdir -p $COMPOSER_HOME && \
#    chown -R www-data:www-data $COMPOSER_HOME

#RUN set -ex && \
#    composer global require \
#        "fxp/composer-asset-plugin:~1.2" \
#        "hirak/prestissimo"

# Setup application sources
USER www-data
WORKDIR ${HOME_SITE}
#COPY .dist /home/site/wwwroot
RUN set -ex && \
    wget https://github.com/oroinc/${APPLICATION_NAME}/releases/download/${APPLICATION_VERSION}/${APPLICATION_DISTRIBUTIVE} && \
    tar -C ${HOME_SITE} --strip-components=1 -xjf ${APPLICATION_DISTRIBUTIVE} ${APPLICATION_NAME} && \
    rm -rf ${APPLICATION_DISTRIBUTIVE}

USER root
ADD .build/php-cli.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-custom.ini
ADD .build/php-fpm.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini
ADD .build/symfony-intl.patch /home/site/patches/symfony-intl.patch

# @see https://github.com/oroinc/platform/issues/912
RUN patch -s -p0 < /home/site/patches/symfony-intl.patch

RUN set -ex && \
    /bin/bash -c "/usr/bin/mysqld_safe --skip-grant-tables &" && \
    sleep 5 && \
# Configure Application parameters
# For PGSQL instalation see https://github.com/vtsykun/docker-orocommerce/blob/master/4.2/Dockerfile#L46
# Create a fake database
#    RUN set -eux; \
#        /etc/init.d/postgresql start; sleep 15;\
#        psql -U postgres -h 127.0.0.1 -c "CREATE DATABASE test;"; \
#        psql -U postgres -h 127.0.0.1 -d test -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'; \
#        find config -type f -name 'parameters.yml' \
#            -exec sed -i "s/database_driver"\:".*/database_driver"\:" pdo_pgsql/g; s/database_name"\:".*/database_name"\:" test/g; s/database_user"\:".*/database_user"\:" postgres/g; s/database_password"\:".*/database_password"\:" postgres/g;" {} \; ;\
#        sudo -u www-data php bin/console oro:assets:install --env=prod --timeout=1800 --symlink; \
#        rm -rf var/cache/* var/logs/* vendor/oro/platform/build/node_modules
    php -r "new PDO('mysql:hostname=127.0.0.1;dbname=oro_database', 'root');" && \
    sed -i -e 's/database_driver: .*/database_driver: pdo_mysql /g' /home/site/wwwroot/app/config/parameters.yml && \
    sed -i -e 's/database_user: .*/database_user: root /g' /home/site/wwwroot/app/config/parameters.yml && \
    sed -i -e 's/database_password: .*/database_password: null /g' /home/site/wwwroot/app/config/parameters.yml && \
    sed -i -e 's/database_host: .*/database_host: 127.0.0.1 /g' /home/site/wwwroot/app/config/parameters.yml && \
    sed -i -e 's/database_name: .*/database_name: oro_database /g' /home/site/wwwroot/app/config/parameters.yml && \
    sed -i -e 's/installed: .*/installed: null /g' /home/site/wwwroot/app/config/parameters.yml && \
# Install application
    sudo -u www-data php app/console oro:install \
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
# Backup database
    mysqldump -u root oro_database > /home/site/database.mysql && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /home/site/wwwroot/app/cache/de* \
        /home/site/wwwroot/app/cache/pr* \
        /home/site/wwwroot/vendor/oro/platform/build/node_modules

RUN set -ex && \
    mkdir -p /run/php && \
    touch /run/php/php${PHP_VERSION}-fpm.sock && \
    touch /run/php/php${PHP_VERSION}-fpm.pid && \
    chmod 777 /run/php/php${PHP_VERSION}-fpm.sock

ADD .build/default.conf /etc/nginx/sites-available/default
COPY ./.build/nginx.conf /etc/nginx/nginx.conf
RUN set -ex && \
    sed -i -e "s/php7.1-fpm.sock;/php$PHP_VERSION-fpm.sock;/g" /etc/nginx/sites-available/default

# Forward request and error logs to docker log collector
RUN set -ex && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log && \
	ln -sf /dev/stderr /var/log/php${PHP_VERSION}-fpm.log

COPY .build/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
RUN set -ex && \
    sed -i -e "s/php7.1-fpm.sock/php${PHP_VERSION}-fpm.sock/g" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
COPY .build/cacert.pem /etc/php/${PHP_VERSION}/cacert.pem

# Configure Log folders
RUN set -ex\
    && test ! -d /home/LogFiles && mkdir -p /home/LogFiles \
    && test ! -d /home/LogFiles/nginx && mkdir -p /home/LogFiles/nginx

# Setup SSH Server
# SSH
ENV SSH_PASSWD "root:Docker!"
RUN echo "$SSH_PASSWD" | chpasswd
COPY .build/sshd_config /etc/ssh/
RUN sed -ri 's/#HostKey \/etc\/ssh\/ssh_host_key/HostKey \/etc\/ssh\/ssh_host_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_dsa_key/HostKey \/etc\/ssh\/ssh_host_dsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/ssh_host_ecdsa_key/g' /etc/ssh/sshd_config && \
    sed -ir 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/g' /etc/ssh/sshd_config && \
    /usr/bin/ssh-keygen -A  && \
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_key && \
    mkdir -p -m0755 /var/run/sshd

#Supervisor configs
RUN rm -rf /etc/supervisor/conf.d/*.ini
COPY ./.build/supervisord/*.conf /etc/supervisor/conf.d/
RUN set -ex && \
    sed -i "s/files\s*=.*/files = \/etc\/supervisor\/conf.d\/\*.conf/g" /etc/supervisor/supervisord.conf && \
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/${PHP_VERSION}/fpm/php-fpm.conf && \
    sed -i -e "s/fpm7/fpm${PHP_VERSION}/g" /etc/supervisor/conf.d/03-php-fpm.conf && \
    sed -i -e "s/php7/php${PHP_VERSION}/g" /etc/supervisor/conf.d/03-php-fpm.conf

COPY .build/bin /usr/bin/
RUN chmod +x /usr/bin/app && \
    chmod +x /usr/bin/init_application.sh && \
    chmod +x /usr/bin/init_container.sh && \
    sed -i -e "s/php7/php${PHP_VERSION}/g" /usr/bin/init_application.sh

# Expose all required ports
# nginx ssh mysql pgsql websocket
EXPOSE 8000 2222 3306 5432 8080

ENTRYPOINT ["init_container.sh"]
