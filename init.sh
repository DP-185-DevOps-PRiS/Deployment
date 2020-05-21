#!/bin/bash

# -----------------------------------------------
# ENTRYPOINT: main
# PARAMETERS: doesn't accept parameters
# TARGET: prepare a new server for deployment and
#         if it was added for load balancing,
#         deploy the application immediately.
# -----------------------------------------------

wait_for_ssh_server_to_start() {
  local EXECUTE=true
  while $EXECUTE; do
    if [ $(service ssh status | grep -c -w "active (running)") -eq 1 ]; then
      EXECUTE=false
    else
      sleep 10
    fi
  done
}

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
  # Waiting for the completion of the script on TeamCity.
  sleep 90
  
  # Set bucket name.
  local BUCKET_NAME=$( cat /opt/kickscooter/init/.gcp/bucket_name )

  # Log in to GCP.
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

install_node_exporter() {
  apt install wget -y
  useradd --no-create-home --shell /bin/false nodeusr
  wget https://github.com/prometheus/node_exporter/releases/download/v1.0.0-rc.1/node_exporter-1.0.0-rc.1.linux-amd64.tar.gz -P /tmp/
  tar xvfz /tmp/node_exporter-1.0.0-rc.1.linux-amd64.tar.gz -C /opt/
  cp -a /opt/node_exporter-1.0.0-rc.1.linux-amd64/node_exporter /usr/local/bin/
  chown -R nodeusr:nodeusr /usr/local/bin/node_exporter
  touch /etc/systemd/system/node_exporter.service
cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter Service
After=network.target
[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable node_exporter
  systemctl start node_exporter
  rm /tmp/node_exporter-1.0.0-rc.1.linux-amd64.tar.gz
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
  docker-compose -f /opt/kickscooter/docker-compose.yml up -d
}

clean_up() {
  rm /opt/kickscooter/*.txt
  rm -R /opt/kickscooter/init/{env,.tc,.gcp,.az,.ssh,.docker}
  rm -R /root/{.ssh,.azure}
}

main() {
  wait_for_ssh_server_to_start
  send_private_ip_to_the_tc
  install_node_exporter
  download_env_files_from_gcs
  update_env_files
  check_acr_for_images || deployment
  clean_up
}

# Entrypoint.
main
