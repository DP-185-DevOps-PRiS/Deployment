#!/bin/bash

# Define needed variables.
init_vars() {

  # List of the services.
  services=(Identity Vehicle Trip Payment Messaging Simulator)

  # List of the ports in use.
  ports=(8080 8081 8082 8083 8084 8088)

  # List with names of the images.
  image_names=(kick-scooter_identity)
  image_names+=(kick-scooter_vehicle)
  image_names+=(kick-scooter_trip)
  image_names+=(kick-scooter_payment)
  image_names+=(kick-scooter_messaging)
  image_names+=(kick-scooter_simulator)

  # List with names of the containers.
  container_names=(kick-scooter_identity_1)
  container_names+=(kick-scooter_vehicle_1)
  container_names+=(kick-scooter_trip_1)
  container_names+=(kick-scooter_payment_1)
  container_names+=(kick-scooter_messaging_1)
  container_names+=(kick-scooter_simulator_1)

  # Read changes in services
  identity=$( cat ./.changes/identity )
  vehicle=$( cat ./.changes/vehicle )
  trip=$( cat ./.changes/trip )
  payment=$( cat ./.changes/payment )
  messaging=$( cat ./.changes/messaging )
  simulator=$( cat ./.changes/simulator )

  # List with changes.
  is_changed=($identity $vehicle $trip $payment $messaging $simulator)
}

# Make it possible to call docker-compose from the script.
docker_compose() {
  docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$PWD:$PWD" \
      -w="$PWD" \
      docker/compose $1 $2
}

# Check if the service is active.
check_services() {
  echo " "
  local i=0 # Index for arrays

  # Go through every service.
  for service in ${services[*]}; do
    echo "Checking $service service ..."

    # Check for changes
    #  1 - yes, 0 - no
    if [ ${is_changed[$i]} -eq 1 ]; then
      echo "New version found for $service service!"
      echo "Checking port ${ports[$i]} ..."

      # Check if the service is active now.
      if [ $(sudo netstat -ntulp | grep -c ${ports[$i]}) -eq 1 ]; then
        echo "Service is active!"
        echo "Stopping the container ..."
        docker stop ${container_names[$i]}
        echo "Removing a container from the list of the containers..."
        docker rm ${container_names[$i]}
        echo "Removing the old image ..."
        docker rmi ${image_names[$i]}
      else
        echo "Service is not active!"
      fi
    else
      echo "No change detected!"
    fi

    (( i++ )) # Move index.
    echo "~~~~~~~~~~~~~~~~~~~~~"
  done
  echo " "
  restart_services
}

restart_services() {
  docker_compose up -d

  # Checking services status.
  sleep 15
  docker_compose ps
  echo " "
}

# Check if the service is ready to accept requests.
availability_check() {
  echo " "
  echo "-------------------------------------------------"
  echo "Checking which services are already available ..."
  echo "-------------------------------------------------"
  execute=true
  while $execute; do
    health_counter=0 # Must equal 6 to complete the check.
    for service in ${container_names[*]}; do
      if [ $(docker logs $service | grep -c "Tomcat started") -eq 1 ]; then
        echo "$service - available"
        (( health_counter++  ))
      else
        echo "$service - unavailable"
      fi
    done

    if [ $health_counter -eq 6 ]; then
      execute=false
    else
      echo " "
      echo "------------------------------------------------------------"
      echo "Waiting for changes, some services are still unavailable ..."
      echo "------------------------------------------------------------"
      sleep 10
    fi
  done
}

main() {
  init_vars
  check_services
  availability_check
}

# Entrypoint.
#main

echo "deploy.sh executing ..."