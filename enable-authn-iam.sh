#!/bin/bash

SERVICE_ID=$1
AWS_ACCOUNT=$2
IAM_ROLE_NAME=$3

CONJUR_CONFIG_FILE="/opt/conjur/etc/conjur.conf"

if [ $# -ne 3 ]; then
    echo "Error invalid number of arguments"
    echo "Usage: ./enable-iam.sh serviceId awsAccount Iam-Role-Name"
    echo "Example: ./enable-iam.sh dev 56748839373318 ubuntu-conjur-iam"
    exit 1
fi

mkdir policies

# Replace the placeholders
sed "s/{{ SERVICE_ID }}/$SERVICE_ID/g" templates/authn-iam.yaml.template > ./policies/authn-iam.yaml

sed "s/{{ AWS_ACCOUNT }}/$AWS_ACCOUNT/g" templates/cust-portal.yaml.template | 
    sed "s/{{ IAM_ROLE_NAME }}/$IAM_ROLE_NAME/g" > ./policies/cust-portal.yaml

sed "s/{{ AWS_ACCOUNT }}/$AWS_ACCOUNT/g" templates/authn-grant.yaml.template | 
    sed "s/{{ IAM_ROLE_NAME }}/$IAM_ROLE_NAME/g" |
    sed "s/{{ SERVICE_ID }}/$SERVICE_ID/g" > ./policies/authn-grant.yaml

# Copy policies to conjur cli
docker cp ./policies conjur-cli:/policies

# Load each of the policies
docker exec conjur-cli conjur policy load root /policies/authn-iam.yaml
docker exec conjur-cli conjur policy load root /policies/cust-portal.yaml
docker exec conjur-cli conjur policy load root /policies/authn-grant.yaml

# update the conjur master environment variables
res=$(docker exec conjur-master cat $CONJUR_CONFIG_FILE | grep "CONJUR_AUTHENTICATORS")
if [ "$res" == "" ]; then
    authenticators=$(echo "CONJUR_AUTHENTICATORS=authn,authn-iam/$SERVICE_ID")
    sudo docker exec conjur-master bash -c "echo $authenticators | tee -a $CONJUR_CONFIG_FILE"
else
    authenticators=$(echo "$res,authn-iam/$SERVICE_ID")
    $conjurConfig = $(docker exec conjur-master cat $CONJUR_CONFIG_FILE | grep -v "CONJUR_AUTHENTICATORS")
    sudo docker exec conjur-master bash -c "echo $conjurConfig | tee $CONJUR_CONFIG_FILE"
    sudo docker exec conjur-master bash -c "echo $authenticators | tee -a $CONJUR_CONFIG_FILE"
fi

# Restart conjur master
docker exec conjur-master sv restart conjur