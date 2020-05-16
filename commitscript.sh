#!/bin/bash
read -p 'Container that is running: ' containerName
echo Note that you may need to change docker-compose.yml to deploy the correct image 
#echo The container name will remain constant

docker commit $containerName $containerName
docker-compose down
docker-compose up -d

docker exec -it -u 0 $containerName bundle exec rake seek:reindex_all 
docker exec -it -u 0 $containerName bundle exec rake seek:workers:restart
docker exec -it -u 0 $containerName bash
