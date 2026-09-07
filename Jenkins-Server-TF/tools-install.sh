#!/bin/bash
set -e

##############################################################################
# DevOps Toolchain Setup Script
# Installs: Java, Jenkins, Docker, SonarQube (container), AWS CLI, kubectl,
#           eksctl, Terraform, Trivy, Helm
##############################################################################

##############################
# Installing Java
##############################
sudo apt update -y
sudo apt install -y curl unzip
sudo apt install -y fontconfig openjdk-21-jre
java -version

##############################
# Installing Jenkins
##############################
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

##############################
# Installing Docker
##############################
PKGS_TO_REMOVE=$(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc 2>/dev/null | cut -f1)
if [ -n "$PKGS_TO_REMOVE" ]; then
  sudo apt remove -y $PKGS_TO_REMOVE
fi

# Remove any old-format Docker apt list left over from a previous run,
# to avoid "Target Packages ... configured multiple times" warnings
sudo rm -f /etc/apt/sources.list.d/docker.list

# Add Docker's official GPG key
sudo apt update -y
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository to Apt sources
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# If you don't want to install Jenkins natively, you can instead run it as a container:
# docker run -d -p 8080:8080 -p 50000:50000 --name jenkins-container jenkins/jenkins:lts

##############################
# Running SonarQube (Docker container)
##############################
docker rm -f sonar 2>/dev/null || true
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community

##############################
# Installing AWS CLI
##############################
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

##############################
# Installing kubectl
##############################
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl

##############################
# Installing eksctl
##############################
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

##############################
# Installing Terraform
##############################
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

##############################
# Installing Trivy
##############################
sudo apt-get install -y wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

##############################
# Installing Helm
##############################
HELM_BUILDKITE_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

sudo apt-get install --yes curl gpg apt-transport-https

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "${TMPDIR:-/tmp}/helm.gpg"

# Ensure that the key ID matches to prevent a repository compromise from establishing an attacker controlled key
if [ "$(gpg --show-keys --with-colons "${TMPDIR:-/tmp}/helm.gpg" | awk -F: '$1 == "fpr" {print $10}' | head -n 1)" != "${HELM_BUILDKITE_APT_KEY_ID}" ]; then
  echo "ERROR: Unexpected Helm APT key ID: potential key compromise"
  exit 1
fi

cat "${TMPDIR:-/tmp}/helm.gpg" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install -y helm

echo "DevOps toolchain installation completed successfully."

squ_6ca3450b35ad734b609101c6c3ba9de541e77e19

sonar-scanner \
  -Dsonar.projectKey=frontend \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://174.129.65.192:9000 \
  -Dsonar.login=squ_6ca3450b35ad734b609101c6c3ba9de541e77e19

  sonar-scanner \
  -Dsonar.projectKey=backend \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://174.129.65.192:9000 \
  -Dsonar.login=squ_6ca3450b35ad734b609101c6c3ba9de541e77e19


