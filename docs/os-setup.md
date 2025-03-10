# OS-Specific Setup Instructions

This guide provides detailed setup instructions for different operating systems to work with the k8s-gitops repository.

## macOS

### Prerequisites
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install kubectl minikube docker argocd git helm

# Install Docker Desktop (alternatively)
brew install --cask docker

# Start Docker Desktop
open -a Docker
```

### Repository Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/k8s-gitops.git
cd k8s-gitops

# Set up environment file
cp scripts/config.env.example scripts/config.env
vim scripts/config.env  # Edit with your settings
```

### Environment Configuration
```bash
# Add to ~/.zshrc or ~/.bash_profile
export PATH="/usr/local/bin:$PATH"
export KUBECONFIG="$HOME/.kube/config"

# You might want to add Docker Hub credentials
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-password"
```

### Starting the Environment
```bash
# Start Minikube
minikube start --memory=4096 --cpus=2

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f bootstrap/argocd/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Access at https://localhost:8443
```

### Common Issues
1. **Docker Desktop Not Starting**
   ```bash
   # Reset Docker Desktop
   killall Docker && open -a Docker
   ```

2. **Permission Issues**
   ```bash
   # Fix directory permissions
   sudo chown -R $USER ~/.docker
   sudo chmod -R g+rwx ~/.docker
   ```

3. **Port Conflicts**
   ```bash
   # Check if ports are in use
   lsof -i :8443
   lsof -i :8081
   
   # Use alternative ports if needed
   kubectl port-forward svc/argocd-server -n argocd 9443:443
   ```

## Linux (Ubuntu/Debian)

### Prerequisites
```bash
# Update package list
sudo apt-get update

# Install Docker
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
```

### Install Kubernetes Tools
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

### Repository Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/k8s-gitops.git
cd k8s-gitops

# Set up environment file
cp scripts/config.env.example scripts/config.env
nano scripts/config.env  # Edit with your settings
```

### Environment Configuration
```bash
# Add to ~/.bashrc or ~/.profile
export PATH="/usr/local/bin:$PATH"
export KUBECONFIG="$HOME/.kube/config"
```

### Common Issues
1. **Docker Permission Denied**
   ```bash
   # Fix docker permissions
   sudo chmod 666 /var/run/docker.sock
   
   # Ensure user is in docker group and restart session
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Minikube Driver Issues**
   ```bash
   # Use docker driver
   minikube config set driver docker
   ```

## Windows (with WSL2)

### Prerequisites
1. Install WSL2 (PowerShell as Administrator):
   ```powershell
   wsl --install
   ```

2. Install Ubuntu from Microsoft Store

3. Install Docker Desktop for Windows
   - Enable WSL2 integration in settings

4. In Ubuntu WSL2:
   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

   # Install minikube
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube

   # Install ArgoCD CLI
   curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
   rm argocd-linux-amd64
   
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
   ```

### Repository Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/k8s-gitops.git
cd k8s-gitops

# Set up environment file
cp scripts/config.env.example scripts/config.env
nano scripts/config.env  # Edit with your settings
```

### Environment Configuration
```bash
# Add to ~/.bashrc in WSL
export PATH="/usr/local/bin:$PATH"
export KUBECONFIG="$HOME/.kube/config"
```

### Common Issues
1. **Docker Not Available in WSL**
   ```bash
   # Check Docker Desktop settings
   # Enable "Ubuntu" in WSL Integration
   ```

2. **WSL2 Memory Issues**
   Create `.wslconfig` in Windows home directory:
   ```ini
   [wsl2]
   memory=8GB
   processors=4
   ```

## Verification Steps (All OS)

1. **Check Tool Versions**:
   ```bash
   docker --version
   kubectl version --client
   minikube version
   argocd version --client
   helm version
   ```

2. **Verify Kubernetes Access**:
   ```bash
   minikube start
   kubectl get nodes
   ```

3. **Test Docker**:
   ```bash
   docker run hello-world
   ```

4. **Deploy the Repository**:
   ```bash
   # Make deploy script executable
   chmod +x scripts/deploy.sh
   
   # Run deployment
   ./scripts/deploy.sh
   
   # Verify deployment
   kubectl get pods -n hello-app
   ```

5. **Access ArgoCD**:
   ```bash
   # Get initial password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   
   # Port forward
   kubectl port-forward svc/argocd-server -n argocd 8443:443
   ```

## Additional Tools

### Development Tools
```bash
# macOS
brew install kubectx k9s kustomize

# Ubuntu/Debian
sudo apt-get install -y kubectx
GO111MODULE=on go get -u github.com/derailed/k9s
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Windows (WSL)
sudo apt-get install -y kubectx
GO111MODULE=on go get -u github.com/derailed/k9s
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
```

### Debugging Tools
```bash
# macOS
brew install stern jq yq

# Ubuntu/Debian
sudo apt-get install -y jq
GO111MODULE=on go get -u github.com/stern/stern
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Windows (WSL)
sudo apt-get install -y jq
GO111MODULE=on go get -u github.com/stern/stern
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
``` 