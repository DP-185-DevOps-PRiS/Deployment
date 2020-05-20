#!/bin/bash

# Check if the service is active.
check_service() {
  local SERVICE_LIST=(gateway discovery messaging identity payment trip vehicle simulator)
  local PORTS=(80 8761 8081 8082 8083 8084 8085 8086)
  local i=0 # Index for lists

  # Find needed port.
  for s in ${SERVICE_LIST[*]}; do
    if [ $s == $SERVICE ]; then
      break
    fi
    (( i++))
  done

  # Check if the service is active now.
  if [ $(sudo netstat -ntulp | grep -c -w "${PORTS[$i]}") -eq 1 ]; then
    echo "Service is active!"
    echo "Stopping the container ..."
    docker stop $CONTAINER_NAME
    echo "Removing a container from the list of the containers ..."
    docker rm $CONTAINER_NAME
    echo "Removing the old image ..."
    docker rmi $IMAGE_NAME
  else
    echo "Service is not active!"
  fi

  restart_service
}

restart_service() {
  # Create the necessary dependencies if the network doesn't exist
  if [ $(sudo docker network ls | grep -c -w "kickscooter_default") -eq 0 ]; then
    dependencies_list=(zookeeper kafka cadvisor)
    for container in ${dependencies_list[*]}; do
	  docker-compose up --no-deps -d $container
    done
  fi

  docker-compose up --no-deps -d $SERVICE
}

main() {
  # Define needed variables.
  SERVICE=$1
  IMAGE_NAME=kickscooter.azurecr.io/$SERVICE
  CONTAINER_NAME=kickscooter_${SERVICE}_1
  
  # Check if the service is active now.
  check_service
}

# Entrypoint.
main $1
