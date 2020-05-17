#!/bin/bash

# Define needed variables.
init_vars() {

  service=$1
  image_name=kickscooter.azurecr.io/$service
  container_name=kickscooter_${service}_1
}

# Check if the service is active.
check_service() {

  local services=(gateway discovery messaging identity payment trip vehicle simulator)
  local ports=(80 8761 8081 8082 8083 8084 8085 8086)
  local i=0 # Index for lists

  # Find needed port.
  for s in ${services[*]}; do
    if [ $s == $service ]; then
      break
    fi
    (( i++))
  done

  # Check if the service is active now.
  if [ $(sudo netstat -ntulp | grep -c -w "${ports[$i]}") -eq 1 ]; then
    echo "Service is active!"
    echo "Stopping the container ..."
    docker stop $container_name
    echo "Removing a container from the list of the containers ..."
    docker rm $container_name
    echo "Removing the old image ..."
    docker rmi $image_name
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

  docker-compose up --no-deps -d $service
}

main() {
  init_vars $1
  check_service
}

# Entrypoint.
main $1
