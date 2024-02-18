#!/bin/bash

HOST_IP=`ifconfig | awk '/inet 15/{print substr($2,1)}'`
PROXY_IP=http://proxyip:port
NO_PROXY="localhost,127.0.0.1,10.244.0.0/16,10.96.0.0/12,192.168.59.0/24,192.168.39.0/24,192.168.49.0/24,${HOST_IP}"

function info()
{
    echo "==================================================================="
    echo "     $1"
    echo "==================================================================="
}


function option() {
    name=${1//\//\\/}
    value=${2//\//\\/}
    sed -i \
        -e '/^#\?\(\s*'"${name}"'\s*=\s*\).*/{s//\1'"${value}"'/;:a;n;ba;q}' \
        -e '$a'"${name}"'='"${value}" $3
}


function uninstall_minikube()
{
    minikube stop
    minikube delete
    rm -r ~/.kube ~/.minikube
    sudo rm /usr/local/bin/localkube /usr/local/bin/minikube
    systemctl stop '*kubelet*.mount'
    sudo rm -rf /etc/kubernetes/
    docker rm -f $(docker ps -qa)
    docker system prune -af --volumes
}

function check_env()
{
    info "K8s Environment "
    cat /etc/environment
    info "User profile Environment "
    env | grep -i proxy | sort
    info "Docker Service environment "
    cat /etc/systemd/system/docker.service.d/http-proxy.conf
    info "Docker Container environment "
    cat ~/.docker/config.json
}

function init_env()
{
  sudo -E apt-get update
  sudo -E apt-get install apt-transport-https
  sudo -E apt-get install curl
  sudo -E apt-get install net-tools
  sudo -E apt-get upgrade
}

function setup_k8senv()
{
    echo "==> Setup /etc/environment"
cat > /etc/environment <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
export NO_PROXY=$NO_PROXY
export no_proxy=$NO_PROXY
EOF
}

function setup_userenv()
{
    echo "==> Setup proxy to user profile"
    # Add proxy information to .profile
    if [[ ! -f ~/.profile ]]
    then
        touch ~/.profile
    fi
    sed -i '/proxy/d' ~/.profile
    sed -i '/minikube entry /d' ~/.profile
    
    # Add proxy information to .proxy
    option "export http_proxy" $PROXY_IP .profile
    option "export https_proxy" $PROXY_IP .profile
    option "export HTTP_PROXY" $PROXY_IP .profile
    option "export HTTPS_PROXY" $PROXY_IP .profile
    option "export no_proxy" $NO_PROXY .profile
    option "export NO_PROXY" $NO_PROXY .profile

    . .profile
}

function setup_docker_service_env()
    {
    echo "==> Add proxy to docker http-proxy "
    # Add proxy information to docker http-proxy.conf
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_IP}"
Environment="HTTPS_PROXY=${PROXY_IP}"
Environment="NO_PROXY=${NO_PROXY}"
EOF
}

function setup_swap_off()
{
    # Turn off swap
    echo "==> Turn off swap space"
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab
    cat /etc/fstab
}

function install_minikube()
{
    minikube_version=${1:-v1.23.2}
    r=https://api.github.com/repos/kubernetes/minikube/releases
    curl -LO $(curl -s $r | grep -o "http.*download/${minikube_version}/minikube-linux-amd64" | head -n1)

    echo "==> Install minikube "
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
}


function install_minikube_v1.16()
{
    info "   Install docker and conntrack"
    apt-get install -y docker.io
    apt-get install -y conntrack

    echo "==> Download minikube version 1.16.0 "
    curl -LO https://github.com/kubernetes/minikube/releases/download/v1.16.0/minikube-linux-amd64

    echo "==> Install minikube "
    install minikube-linux-amd64 /usr/local/bin/minikube
}

function install_minikube_latest()
{
  #wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  wget https://github.com/kubernetes/minikube/releases/download/v1.25.1/minikube-linux-amd64
  chmod +x minikube-linux-amd64
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube

  #curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.3/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
  sudo mv ./kubectl /usr/bin/kubectl
  kubectl version -o json  --client
}

function restart_minikube()
{
    info "Restart up minikube"
    minikube stop
    unset http_proxy
    unset https_proxy

cat > /etc/environment <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
export http_proxy=""
export https_proxy=""
export no_proxy="$NO_PROXY"
export NO_PROXY="$NO_PROXY"
EOF

    minikube start --vm-driver=none --cni calico --docker-env NO_PROXY=$NO_PROXY
}


function start_minikube()
{
    info "Start up minikube"
    . .profile
    minikube start --vm-driver=none --cni calico --docker-env NO_PROXY=$NO_PROXY
}

function validate_minikube()
{
    info "Verifying minikube installation "

    minikube status

    minikube update-context

    kubectl get pods -A
}


function usage()
{
  echo "Usage"
  echo "$0 [options] [ip]"
  echo "Options "
  echo "1 setup environment"
  echo "2 Install and start install minikube"
  echo "3 Restart minikube"
  echo "6 Uninstall minikube"
}

function main()
{
    install_minikube_latest
    start_minikube
    validate_minikube
}


case $1 in
   1)
       setup_k8senv
       setup_userenv
       setup_docker_service_env
       setup_swap_off
       init_env
       ;;
   2)
       main
       ;;
   3)
       restart_minikube
       ;;
   4)
       check_env
       ;;
   5)
       setup_userenv
       ;;
   6)
       uninstall_minikube
       ;;
   *)
       usage
esac
