#!/bin/bash

cd /var/www/wwwroot && app oro:message-queue:consume -vvv
