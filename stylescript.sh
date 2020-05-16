#!/bin/bash
#is="s"
#containerName="seekprod"
#fileName="new_colors.css"
read -p 'Do you wish to copy an image or a stylesheet?(i/s): ' is
read -p 'Container that is running: ' containerName
read -p 'Filename you wish to copy: ' fileName


recompile_and_commit() {
  echo docker exec -it -u 0 $containerName rm -rf /seek4/public/assets
  docker exec -it -u 0 $containerName rm -rf /seek4/public/assets
  echo docker exec -it -u 0 $containerName bundle exec rake assets:precompile
  docker exec -it -u 0 $containerName bundle exec rake assets:precompile

  docker exec -it -u 0 $containerName chown -R www-data:www-data /seek4/public/
  docker exec -it -u 0 $containerName chmod -R g+w /seek4/public/

  #docker commit $containerName $containerName
  docker exec -it -u 0 $containerName service nginx restart
  #docker-compose down
  #docker-compose up -d
  #docker exec -it -u 0 $containerName bundle exec rake seek:reindex_all 
  #docker exec -it -u 0 $containerName bundle exec rake seek:workers:restart
}

if [ "$is" = "s" ]; then
    echo docker cp /srv/rails/seek4/app/assets/stylesheets/$fileName $containerName:/seek4/app/assets/stylesheets/
    docker cp /srv/rails/seek4/app/assets/stylesheets/$fileName $containerName:/seek4/app/assets/stylesheets/

    echo docker cp /srv/rails/seek4/app/assets/stylesheets/application.css $containerName:/seek4/app/assets/stylesheets/
    docker cp /srv/rails/seek4/app/assets/stylesheets/application.css $containerName:/seek4/app/assets/stylesheets/
    recompile_and_commit

elif [ "$is" = "i" ]; then
    echo docker cp /srv/rails/seek4/app/assets/images/$fileName $containerName:/seek4/app/assets/images/
    docker cp /srv/rails/seek4/app/assets/images/$fileName $containerName:/seek4/app/assets/images/
    recompile_and_commit

else
    echo You must enter i or s
fi
