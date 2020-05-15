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
  local ports=(80 8761 8084 8085 8083 8086 8081 8088)

  # Find needed port.
  local i=0
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
  # Check zookeeper.
  if [ $(sudo netstat -ntulp | grep -c -w "2181") -ne 1 ]; then
    docker-compose up --no-deps -d zookeeper
  fi
  
  # Check kafka.
  if [ $(sudo netstat -ntulp | grep -c -w "9092") -ne 1 ]; then
    docker-compose up --no-deps -d kafka
  fi
  
  docker-compose up --no-deps -d $service
}

main() {
  init_vars $1
  check_service
}

# Entrypoint.
main $1
