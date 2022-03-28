#!/bin/bash
MANAGER_IP=192.168.6.1
sudo apt-get -y update
sudo apt-get -qq --no-install-recommends install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get -y install docker-compose

sudo docker swarm init --advertise-addr=$MANAGER_IP

sudo modprobe mpls_router

while [[ $(sudo docker node ls | awk 'END{print NR}') != $1 ]];
do
    echo "waiting for all worker nodes to join swarm..."
    sleep 10
done
# Create docker registry
docker service create --name registry --publish published=5000,target=5000 registry:2
# Start up services
filename='priority.txt'
while read p; do
    sudo docker-compose -f "containers/${p}/docker-compose.yml" build
    sudo docker-compose -f "containers/${p}/docker-compose.yml" push
    docker service create \
       --name "${p}-wrapper" \
       --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
       --mount type=bind,source="containers/${p}",target=/tmp/ \
       --workdir /tmp/ \
       docker/compose \
       docker-compose up
    echo "Deployed $p to swarm"
done < "$filename"
