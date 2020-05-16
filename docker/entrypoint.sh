#!/bin/bash

# import some shared functions
. docker/shared_functions.sh

# Set the search to be enabled by default
enable_search

# DB config
check_mysql

# Soffice service
start_soffice

# Search
start_or_setup_search

# SETUP for OpenSEEK only, to link to openBIS if necessary
if [ ! -z $OPENBIS_USERNAME ]
then
    bundle exec rake db:seed:openseek:default_openbis_endpoint
fi

# Start Rails
echo "STARTING SEEK"
bundle exec puma -C docker/puma.rb -d

# Workers
if [ -z $NO_ENTRYPOINT_WORKERS ] #Don't start if flag set, for use with docker-compose
then
    echo "STARTING WORKERS"
    bundle exec rake seek:workers:start &
fi


tail -f log/puma.out log/puma.err log/production.log &

echo "STARTING NGINX"
nginx -g 'daemon off;'
