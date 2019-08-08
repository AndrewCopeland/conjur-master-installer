#!/bin/bash

source ./config.env

SERVICE_ID=$1
AWS_ACCOUNT=$2
IAM_ROLE_NAME=$3

CONJUR_CONFIG_FILE="/opt/conjur/etc/conjur.conf"

TEMPLATE_DIR="templates"
TEMPLATE_AUTHN_IAM="$TEMPLATE_DIR/authn-iam.yaml"
TEMPLATE_AUTHN_AWS_PORTAL="$TEMPLATE_DIR/aws-portal.yaml"
TEMPLATE_AUTHN_GRANT="$TEMPLATE_DIR/authn-grant.yaml"

POLICY_DIR="policies"
POLICY_AUTHN_IAM="$POLICY_DIR/authn-iam.yaml"
POLICY_AUTHN_AWS_PORTAL="$POLICY_DIR/aws-portal.yaml"
POLICY_AUTHN_GRANT="$POLICY_DIR/authn-grant.yaml"

if [ $# -ne 3 ]; then
    echo "Error invalid number of arguments"
    echo "Usage: ./enable-authn-iam.sh serviceId awsAccount Iam-Role-Name"
    echo "Example: ./enable-authn-iam.sh dev 56748839373318 ubuntu-conjur-iam"
    exit 1
fi


# Replace the placeholders
sed "s/{{ SERVICE_ID }}/$SERVICE_ID/g" $TEMPLATE_AUTHN_IAM > $POLICY_AUTHN_IAM

sed "s/{{ AWS_ACCOUNT }}/$AWS_ACCOUNT/g" $TEMPLATE_AUTHN_AWS_PORTAL | 
    sed "s/{{ IAM_ROLE_NAME }}/$IAM_ROLE_NAME/g" > $POLICY_AUTHN_AWS_PORTAL

sed "s/{{ AWS_ACCOUNT }}/$AWS_ACCOUNT/g" $TEMPLATE_AUTHN_GRANT | 
    sed "s/{{ IAM_ROLE_NAME }}/$IAM_ROLE_NAME/g" |
    sed "s/{{ SERVICE_ID }}/$SERVICE_ID/g" > $POLICY_AUTHN_GRANT

# Copy policies to conjur cli
docker cp ./policies conjur-cli:/policies

# Load each of the policies
docker exec conjur-cli conjur policy load root $POLICY_AUTHN_IAM
docker exec conjur-cli conjur policy load root $POLICY_AUTHN_AWS_PORTAL
docker exec conjur-cli conjur policy load root $POLICY_AUTHN_GRANT

# update the conjur master environment variables
res=$(docker exec conjur-master cat $CONJUR_CONFIG_FILE | grep "CONJUR_AUTHENTICATORS")
if [ "$res" == "" ]; then
    authenticators=$(echo "CONJUR_AUTHENTICATORS=authn,authn-iam/$SERVICE_ID")
    docker exec conjur-master bash -c "echo $authenticators | tee -a $CONJUR_CONFIG_FILE"
else
    authenticators=$(echo "$res,authn-iam/$SERVICE_ID")
    conjurConfig=$(docker exec conjur-master cat $CONJUR_CONFIG_FILE | grep -v "CONJUR_AUTHENTICATORS")
    docker exec conjur-master bash -c "echo $conjurConfig | tee $CONJUR_CONFIG_FILE"
    docker exec conjur-master bash -c "echo $authenticators | tee -a $CONJUR_CONFIG_FILE"
fi

# Restart conjur master
docker exec conjur-master sv restart conjur

# Get the environment variables needed for AWS
echo "Environment Variables for AWS instance"

cat << EOF
export CONJUR_APPLIANCE_URL=https://$CONJUR_MASTER_NAME
export AUTHN_IAM_SERVICE_ID=$SERVICE_ID
export CONJUR_AUTHN_LOGIN=host/aws-portal/$AWS_ACCOUNT/$IAM_ROLE_NAME
export CONJUR_CERT_FILE=./conjur-$CONJUR_ACCOUNT.pem
export CONJUR_ACCOUNT=$CONJUR_ACCOUNT
EOF