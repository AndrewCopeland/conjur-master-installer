#!/bin/bash
source ./config.env

function get_os_id() {
    os_id=$(cat /etc/*-release | grep "^ID=" | awk -F '"' '{print $2}')
    return $os_id
}

function get_os_version() {
    version=$(cat /etc/*-release | grep "^VERSION_ID=" | awk -F '"' '{print $2}')
    return $version
}

function get_os_type() {
    os=$(get_os_id)
    version=$(get_os_version)
    return "$os $version"
}

function install_dependancies_rhel_7_6() {
    yum update -y
    yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.74-1.el7.noarch.rpm
    yum install yum-utils device-mapper-persistent-data lvm2 -y
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install docker-ce -y
    # This needs to be done because SELinux blocks docker from running
    setenforce Permissive
    systemctl start docker
    systemctl enable /usr/lib/systemd/system/docker.service
}

function create_conjur_master_rhel_7_6() {
    # get the image we will be using for the conjur master
    tarname=$(find conjur-app*)
    conjur_image=$(sudo docker load -i $tarname)
    conjur_image=$(echo $conjur_image | sed 's/Loaded image: //')

    # start the conjur master
    docker network create conjur
    docker container run -d --name $CONJUR_MASTER_NAME --network $DOCKER_NETWORK_NAME --restart=always --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $conjur_image
    docker exec $CONJUR_MASTER_NAME evoke configure master --hostname $CONJUR_MASTER_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT
}

function create_and_configure_conjur_cli() {
    #create CLI container
    sudo docker container run -d --name conjur-cli --network $DOCKER_NETWORK_NAME --restart=always --entrypoint "" cyberark/conjur-cli:5 sleep infinity
    sudo docker exec -i conjur-cli conjur init --account $company_name --url https://$master_name <<< yes
    sudo docker exec conjur-cli conjur authn login -u admin -p $admin_password
}

function install_conjur() {
    os_type=$(get_os_type)
    echo "OS: $os_type"

    case $(echo "$os_type") in
    'rhel 7.6' )
        install_dependancies_rhel_7_6
        create_conjur_master_rhel_7_6
        create_and_configure_conjur_cli
        ;;
    esac
}

install_conjur