#!/bin/bash

# Installs minikube


HOST_IP=`hostname -I  | awk '{print substr($1,1)}'`
PROXY=http://proxy-in.its.hpecorp.net:443
NO_PROXY=localhost,127.0.0.1,10.244.0.0/16,10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24,$HOST_IP

function option() {
    name=${1//\//\\/}
    value=${2//\//\\/}
    sed -i \
        -e '/^#\?\(\s*'"${name}"'\s*=\s*\).*/{s//\1'"${value}"'/;:a;n;ba;q}' \
        -e '$a'"${name}"'='"${value}" $3
}



echo "==================================================================="
echo "Disable firewall and ipv6 "
echo "==================================================================="

# Set up required sysctl params
  sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

  sudo tee /etc/sysctl.d/sysctl.conf<<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
sudo sysctl -p
EOF

echo "==> Setup /etc/environments"
cat > /etc/environment <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
export http_proxy=${PROXY}
export https_proxy=${PROXY}
export no_proxy=$NO_PROXY
export NO_PROXY=$NO_PROXY
EOF

echo "==> Setup proxy to user profile"
# Add proxy information to .proxy
option "export http_proxy" $PROXY .profile
option "export https_proxy" $PROXY .profile
option "export no_proxy" $NO_PROXY .profile
option "export NO_PROXY" $NO_PROXY .profile

. .profile

echo "==> Add proxy to docker http-proxy "
# Add proxy information to docker http-proxy.conf
cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY}"
Environment="HTTPS_PROXY=${PROXY}"
Environment="NO_PROXY=$NO_PROXY"
EOF

# Turn off swap
echo "==> Turn off swap space"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
cat /etc/fstab

echo "==================================================================="
echo "==> Install docker and conntrack"
echo "==================================================================="
sudo apt-get install -y docker.io
sudo apt-get install -y conntrack

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

apt-get install -y kubelet kubeadm


echo "==================================================================="
echo "==> Download and install minikube version 1.28.0 "
echo "==================================================================="
set -x
minikube_version=v1.23.2
r=https://api.github.com/repos/kubernetes/minikube/releases
curl -LO $(curl -s $r | grep -o "http.*download/${minikube_version}/minikube-linux-amd64" | head -n1)

#curl -LO https://github.com/kubernetes/minikube/releases/download/v1.16.0/minikube-linux-amd64

echo "==> Install minikube "
sudo install minikube-linux-amd64 /usr/local/bin/minikube


echo "==> Start up minikube "
minikube start --vm-driver=none --memory=2048 --docker-env NO_PROXY=$NO_PROXY

# Restarting the minikube and disabling the proxy to ensure DNS service starts
echo "==> Restart the minikube "
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

minikube start --memory=2048 --docker-env NO_PROXY=$NO_PROXY

echo "==================================================================="
echo "Install minikube - COMPLETE "
echo "==================================================================="

echo "==> Verifying minikube installation "

minikube status

minikube update-context

kubectl get pods -A

