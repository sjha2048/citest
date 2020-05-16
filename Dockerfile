FROM ruby:2.4

MAINTAINER Stuart Owen <orcid.org/0000-0003-2130-0865>, Finn Bacall

ENV APP_DIR /seek4
ENV RAILS_ENV=production 

# need to set the locale, otherwise some gems file to install
ENV LANG="en_US.UTF-8" LANGUAGE="en_US:UTF-8" LC_ALL="C.UTF-8"

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential vim git \
		libcurl4-gnutls-dev libmagick++-dev libpq-dev libreadline-dev \
		libreoffice libsqlite3-dev libssl-dev libxml++2.6-dev \
		libxslt1-dev locales mysql-client nginx nodejs openjdk-8-jdk \
		poppler-utils postgresql-client sqlite3 links telnet vim-tiny  && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8

RUN mkdir -p $APP_DIR
RUN chown www-data $APP_DIR

USER www-data

WORKDIR $APP_DIR

# Bundle install throw errors if Gemfile has been modified since Gemfile.lock
COPY Gemfile* ./
RUN bundle config --local frozen 1 && \
    bundle install --deployment --without development test

# App code
COPY . .
RUN mkdir log tmp
COPY docker/virtuoso_settings.docker.yml config/virtuoso_settings.yml

USER root
RUN chown -R www-data solr config docker public /var/www db/schema.rb
USER www-data
RUN touch config/using-docker #allows us to see within SEEK we are running in a container

# SQLite Database (for asset compilation)
RUN mkdir sqlite3-db && \
    cp docker/database.docker.sqlite3.yml config/database.yml && \
    chmod +x docker/upgrade.sh docker/start_workers.sh && \
    bundle exec rake db:setup


#advanced search
USER root
RUN bundle exec rails g controller advanced_searches
COPY docker/advanced_searches_controller.rb app/controllers/
RUN bundle exec rails g model advanced_search keywords:string search_type:string min_due_date:date max_due_date:date institution:string discipline:string tool:string city:string expertise:string
RUN bundle exec rails g migration AddTargetCompletionToProject target_completion:date
RUN bundle exec rails g migration AddProjectStatusToAdvancedSearch project_status:string
RUN bundle exec rails g migration AddBrowseTypeToAdvancedSearch browse_type:string
RUN bundle exec rails g migration AddProjectStatusToProject project_status:string
RUN bundle exec rake db:migrate 

#RUN bundle exec rake tmp:clear
RUN rm -rf public/assets
RUN bundle exec rake assets:precompile && \
    rm -rf tmp/cache/*

#root access needed for next couple of steps
USER root
RUN chown -R www-data:www-data public/
RUN chmod -R g+w public/

# NGINX config
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Cleanup
RUN rm -rf /tmp/* /var/tmp/*

USER www-data

# Network
EXPOSE 3000

# Shared
VOLUME ["/seek4/filestore", "/seek4/sqlite3-db", "/seek4/tmp/cache"]

CMD ["docker/entrypoint.sh"]

#RUN bundle exec rake seek:reindex_all
