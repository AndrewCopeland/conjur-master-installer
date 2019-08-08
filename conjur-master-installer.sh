#!/bin/bash
source ./config.env

function get_os_id() {
    os_id=$(cat /etc/*-release | grep "^ID=" | awk -F '"' '{print $2}')
    echo "$os_id"
}

function get_os_version() {
    version=$(cat /etc/*-release | grep "^VERSION_ID=" | awk -F '"' '{print $2}')
    echo "$version"
}

function get_os_type() {
    os=$(get_os_id)
    version=$(get_os_version)
    echo "$os $version"
}

function install_dependancies_rhel() {
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

function create_conjur_master_rhel_7() {
    # get the image we will be using for the conjur master
    tarname=$(find conjur-app*)
    conjur_image=$(sudo docker load -i $tarname)
    conjur_image=$(echo $conjur_image | sed 's/Loaded image: //')

    # start the conjur master
    docker network create $DOCKER_NETWORK_NAME
    docker container run -d --name $CONJUR_MASTER_NAME --network $DOCKER_NETWORK_NAME --restart=always --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $conjur_image
    docker exec $CONJUR_MASTER_NAME evoke configure master --hostname $CONJUR_MASTER_NAME --admin-password $ADMIN_PASSWORD $CONJUR_ACCOUNT
}

function create_and_configure_conjur_cli() {
    #create CLI container
    docker container run -d --name conjur-cli --network $DOCKER_NETWORK_NAME --restart=always --entrypoint "" cyberark/conjur-cli:5 sleep infinity
    docker exec -i conjur-cli conjur init --account $CONJUR_ACCOUNT --url https://$CONJUR_MASTER_NAME <<< yes
    docker exec conjur-cli conjur authn login -u admin -p $ADMIN_PASSWORD
}

function install_conjur_rhel_7() {
    install_dependancies_rhel
    create_conjur_master_rhel_7
    create_and_configure_conjur_cli
}

function validate_no_arm() {
    which_bash=$(which bash)
    arm=$(file $which_bash | grep ARM)

    if [ "$arm" != "" ]; then
        echo "ARM is not supported for conjur"
        exit 1
    fi
}

function delete_conjur() {
    docker rm -f $(docker ps -a -q)
    docker rmi -f $(docker images -q)
}

function get_conjur_cert() {
    docker cp conjur-cli:/root/conjur-$CONJUR_ACCOUNT.pem ./
}

function install_conjur() {
    validate_no_arm

    os_type=$(get_os_type)
    echo "OS: $os_type"

    delete_conjur

    case $(echo "$os_type") in
    'rhel 7.1' )
        install_conjur_rhel_7
        ;;
    'rhel 7.7' )
        install_conjur_rhel_7
        ;;
    esac

    # add conjur master to hosts file
    echo "127.0.0.1    $CONJUR_MASTER_NAME" >> /etc/hosts

    get_conjur_cert

    # set the environment variables needed for the python3 client
    set_env_var_for_conjur_client
}

install_conjur