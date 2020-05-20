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
  hostname -I | awk '{print $1}' > /opt/kickscooter/"$(hostname).txt"

  # Set variables for connection via scp.
  local USERNAME=$( cat /opt/kickscooter/init/.tc/username )
  local IP=$( cat /opt/kickscooter/init/.tc/ip )

  # Send file.
  scp /opt/kickscooter/*.txt $USERNAME@$IP:/root/IPs/AzureScaleSet
}

download_env_files_from_gcs() {
  # Set bucket name.
  local BUCKET_NAME=$( cat /opt/kickscooter/init/.gcp/bucket_name )

  # Login to GCP.
  gcloud auth activate-service-account \
    --quiet \
    --key-file /opt/kickscooter/init/.gcp/key.json

  # Download env-files.
  gsutil -q cp -r gs://$BUCKET_NAME/env /opt/kickscooter/init
}

update_env_files() {
  # Set EUREKA_IP value.
  local EUREKA_IP=$( cat /opt/kickscooter/*.txt )

  # Create env folder for final values.
  mkdir /opt/kickscooter/env

  # Copy the current file for kafka.
  cp /opt/kickscooter/init/env/kafka.env /opt/kickscooter/env

  # Set services names.
  local service_list=(gateway identity messaging payment simulator trip vehicle)

  # Update EUREKA_SERVER value in all env-files.
  for service in ${service_list[*]}; do
    sed "s|eureka|$EUREKA_IP|" /opt/kickscooter/init/env/${service}.env > /opt/kickscooter/env/${service}.env
  done
}

check_acr_for_images() {
  # Set variables to log in to Azure.
  local CLIENT_ID=$( cat /opt/kickscooter/init/.az/client_id )
  local CLIENT_SECRET=$( cat /opt/kickscooter/init/.az/client_secret )
  local TENANT_ID=$( cat /opt/kickscooter/init/.az/tenant_id )

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
  local URI=$( cat /opt/kickscooter/init/.docker/uri )
  local USERNAME=$( cat /opt/kickscooter/init/.docker/username )
  local PASSWORD=$( cat /opt/kickscooter/init/.docker/password )
  docker login -u $USERNAME -p $PASSWORD $URI
  docker-compose up -d
}

clean_up() {
 rm /opt/kickscooter/*.txt
 rm -R /opt/kickscooter/init/env
 #rm -R init/.tc init/.gcp init/.az
 #rm -R init/.ssh init/.docker
 rm -R /root/.azure
}

main() {
  send_private_ip_to_the_tc
  download_env_files_from_gcs
  update_env_files
  check_acr_for_images || deployment
  clean_up
}

# Entrypoint.
main
