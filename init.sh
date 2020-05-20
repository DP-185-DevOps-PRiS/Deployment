#!/bin/bash

# -----------------------------------------------
# ENTRYPOINT: main
# PARAMETERS: doesn't accept parameters
# TARGET: prepare a new server for deployment and
#         if it was added for load balancing,
#         deploy the application immediately.
# -----------------------------------------------

send_private_ip_to_the_tc() {
  # Save private ip in file.
  hostname -I | awk '{print $1}' > "$(hostname).txt"

  # Set variables for connection via scp.
  local USERNAME=$( cat .tc/username )
  local IP=$( cat .tc/ip )

  # Send file.
  scp -o LogLevel=ERROR *.txt $USERNAME@$IP:/root/IPs/AzureScaleSet
}

download_env_files_from_gcs() {
  # Set bucket name.
  local BUCKET_NAME=$( cat .gcp/bucket_name )

  # Login to GCP.
  gcloud auth activate-service-account \
    --quiet \
    --key-file .gcp/key.json

  # Download env-files.
  gsutil -q cp -r gs://$BUCKET_NAME/env .
}

update_env_files() {
  # Set EUREKA_IP value.
  local EUREKA_IP=$( cat *.txt )

  # Create env folder for final values.
  mkdir $PATH_TO_APP/env && chmod 700 $PATH_TO_APP/env

  # Copy the current file for kafka.
  cp env/kafka.env $PATH_TO_APP/env

  # Set services names.
  local service_list=(gateway identity messaging payment simulator trip vehicle)

  # Update EUREKA_SERVER value in all env-files.
  for service in ${service_list[*]}; do
    sed "s|eureka|$EUREKA_IP|" env/${service}.env > $PATH_TO_APP/env/${service}.env
  done
}

check_acr_for_images() {
  # Set variables to log in to Azure.
  local CLIENT_ID=$( cat .az/client_id )
  local CLIENT_SECRET=$( cat .az/client_secret )
  local TENANT_ID=$( cat .az/tenant_id )

  # Log in to Azure.
  az login --output none --service-principal \
           --username "${CLIENT_ID}" \
           --password "${CLIENT_SECRET}" \
           --tenant "${TENANT_ID}"

  # Check the ACR.
  if [ $(az acr repository list -n kickscooter | grep -c ,) -eq 7 ]; then
    return 1
  else
    return 0
  fi
}

deployment() {
  local URI=$( cat .docker/uri )
  local USERNAME=$( cat .docker/username )
  local PASSWORD=$( cat .docker/password )
  docker login -u $USERNAME -p $PASSWORD $URI
  docker-compose -f $PATH_TO_APP/docker-compose.yml up -d
}

clean_up() {
 rm *.txt
 rm -R env
 rm -R .tc .gcp .az .ssh .docker
 rm -R /root/.ssh /root/.azure
}

main() {
  PATH_TO_APP="/opt/kickscooter"
  
  send_private_ip_to_the_tc
  download_env_files_from_gcs
  update_env_files
  check_acr_for_images || deployment
  clean_up
}

# Entrypoint.
main
