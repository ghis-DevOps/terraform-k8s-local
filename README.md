# terraform-k8s-local



DevOps CI/CD Pipeline - Terraform + Kubernetes + EKS
End-to-end CI/CD pipeline from your whiteboard design: GitHub -> GitHub Actions -> Security Scan -> Docker Artifacts -> ECR/JFrog -> ECS/EKS -> Vault

This repo implements your hand-written architecture:

VCS: GitHub
CI Build: GitHub Actions
Scan: Trivy, Gitleaks, SonarQube
Artifact: Jar file, Docker Image
Artifactory: JFrog + AWS ECR
Deploy: GitHub Actions -> ECS / EKS (with ArgoCD option)
Credentials: GitHub Secrets + HashiCorp Vault
IaC: Terraform for JFrog, Vault Server, ECS/EKS, and App
Architecture
Developer Push
      |
      v
GitHub (VCS)
      |
      v
GitHub Actions (CI Build)
      |
      +---> Scan: Trivy (image) + Gitleaks (secrets) + SonarQube (code quality)
      |
      v
Build Artifact: Jar / Docker Image
      |
      v
Artifactory: ECR + JFrog (AWS Access?)
      |
      v
Deploy Tool: GitHub Actions -> EKS / ECS
             + ArgoCD (GitOps option)
      |
      v
Kubernetes: App1 + App2 (2 replicas each)
      |
      v
Credentials: GitHub Secret + Vault Admin
Tools Mapping from Diagram:

Function	Tool in Diagram	Tool in this Repo
VCS	GitHub	GitHub
CI Build	GitHub Action	GitHub Actions
Security Scan	Trivy, Gitleaks, SonarQube	Trivy
Artifact	Jar, Docker Image	Docker Image (nginx, httpd)
Artifactory	JFrog and ECR	AWS ECR + JFrog module
Deploy	GitHub Action -> ECS	Terraform + kubectl / EKS
Credentials	GitHub Secret / Vault	GitHub Secrets + Vault Helm
IaC	Terraform -> ECS, Vault	Terraform Modules
Prerequisites
Local (Free)
Windows 10/11 + PowerShell as Admin
Docker Desktop (Running) - Enable Kubernetes in Settings
kubectl: winget install -e --id Kubernetes.kubectl
Terraform: winget install -e --id HashiCorp.Terraform
k9s (optional): winget install -e --id derailed.k9s
FreeLens / OpenLens 6.5.2-366: winget install -e --id Freelens.Freelens
Trivy (for scanning): winget install -e --id AquaSecurity.Trivy
AWS (Paid - ~$70/mo for EKS)
AWS CLI: winget install -e --id Amazon.AWSCLI
aws configure with Access Key + Secret
Terraform + kubectl (same as local)
Project Structure
terraform-k8s-local/       # PART 1 - Local Kubernetes (Docker Desktop)
├── main.tf                # Uses module app1 + app2
├── variables.tf
└── modules/
    └── app/
        ├── main.tf        # Reusable Deployment + Service
        └── variables.tf
terraform-demo-aws/        # PART 2 - AWS Cloud (VPC + ECR + EKS)
├── main.tf                # VPC + ECR + EKS + App modules
├── variables.tf
├── outputs.tf
└── modules/
    └── app/               # SAME module as local! Reused.
        ├── main.tf
        └── variables.tf
k8s-demo/                  # Plain YAML version (no Terraform)
├── app1.yaml
└── app2.yaml
Why Modules?
Instead of typing 10x kubectl commands, you write 1 module and reuse it:

module "app1" { source = "./modules/app" app_name = "app1" image = "nginx:1.25" }
module "app2" { source = "./modules/app" app_name = "app2" image = "httpd:2.4" }
module "app3" { source = "./modules/app" app_name = "app3" image = "my-ecr/app3:latest" }
Quick Start - PART 1: Local (Docker Desktop)
No cloud cost, perfect for learning.

Enable Kubernetes in Docker Desktop
Docker Desktop -> Settings -> Kubernetes -> Enable Kubernetes -> Apply & Restart
Set context and verify
kubectl config use-context docker-desktop
kubectl get nodes
# Should show: docker-desktop Ready
Deploy with Terraform Modules
cd terraform-k8s-local
terraform init
terraform validate
terraform plan
terraform apply
kubectl get pods
# Expected: 4 pods Running (2x app1, 2x app2)
View in k9s and FreeLens
k9s  # type :pods to see app1 + app2, press l for logs, s for shell
FreeLens: Open -> Cluster docker-desktop -> Workloads -> Pods
Open in browser
kubectl port-forward svc/app1 8081:80
# Browser: http://localhost:8081
kubectl port-forward svc/app2 8082:80
# Browser: http://localhost:8082
Cleanup
terraform destroy
Quick Start - PART 2: AWS (ECR + EKS)
Builds VPC + ECR + EKS cluster - Takes 15-20 mins.

Login to AWS
aws configure
aws sts get-caller-identity
Deploy
cd terraform-demo-aws
terraform init
terraform apply -auto-approve
aws eks update-kubeconfig --name devops-cluster --region us-east-1
kubectl get nodes
View
k9s --context devops-cluster
FreeLens -> Add Cluster -> Select ~/.kube/config -> devops-cluster
Get ECR URLs
terraform output ecr_app1_url
terraform output ecr_app2_url
Cleanup to avoid charges
terraform destroy -auto-approve
Security Scanning (From Diagram: Trivy, Gitleaks, SonarQube)
# Scan Docker image before push
trivy image nginx:1.25
trivy image httpd:2.4
# Scan Git repo for secrets (Gitleaks)
# Install: winget install -e --id gitleaks.gitleaks
gitleaks detect --source .
# SonarQube - run in Docker
docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
# Browser: http://localhost:9000 (admin/admin)
In GitHub Actions, this is a step:

- name: Trivy Scan
  run: trivy image --exit-code 1 --severity CRITICAL my-ecr/app1:latest
CI/CD Pipeline - GitHub Actions Workflow
Create .github/workflows/deploy.yml:

name: CI/CD Pipeline
on:
  push:
    branches: [main]
jobs:
  build-scan-push-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker Image
        run: docker build -t app1:${{ github.sha }} .
      - name: Trivy Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: app1:${{ github.sha }}
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
      - name: Gitleaks Scan
        uses: gitleaks/gitleaks-action@v2
      - name: Login to ECR
        run: aws ecr get-login-password | docker login --username AWS --password-stdin ${{ secrets.ECR_URL }}
      - name: Push to ECR / JFrog
        run: |
          docker tag app1:${{ github.sha }} ${{ secrets.ECR_URL }}:latest
          docker push ${{ secrets.ECR_URL }}:latest
      - name: Terraform Deploy to EKS
        run: |
          terraform -chdir=terraform-demo-aws init
          terraform -chdir=terraform-demo-aws apply -auto-approve -var="app1_image=${{ secrets.ECR_URL }}:latest"
Credentials Management (from diagram):

GitHub Secrets: ECR_URL, AWS_ACCESS_KEY, AWS_SECRET_KEY
HashiCorp Vault: Install in EKS for runtime secrets
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --set "server.dev.enabled=true"
Monitoring with k9s and OpenLens/FreeLens
Task	k9s Command	FreeLens UI
List Pods	:pods	Workloads -> Pods
Logs	Select pod -> l	Click Pod -> Logs tab
Shell	Select pod -> s	Click Pod -> Terminal tab
Describe	Select pod -> d	Click Pod -> Events tab
Services	:svc	Network -> Services
All Namespaces	0	Namespace dropdown
Quit	q	Close window
Both read the same file: C:\Users\<You>\.kube\config

Terraform Modules Explained
Why Modules vs Typing Commands?
Without Modules	With Modules
kubectl create deployment app1...	module "app1" { source = "./modules/app" ... }
kubectl expose deployment app1...	Reused for app1, app2, app3, appN
10 commands per app	terraform apply does all
Reusable App Module (modules/app/)
Input: app_name, image, replicas
Output: Deployment + Service (NodePort)

You can extend it:

Add Vault secrets
Add ECR image URL variable
Add Ingress, HPA, ConfigMap
AWS Modules Used
terraform-aws-modules/vpc/aws - VPC + Subnets + NAT
terraform-aws-modules/ecr/aws - ECR Repositories (JFrog alternative)
terraform-aws-modules/eks/aws - EKS Cluster + Node Groups
Troubleshooting
OpenLens won't open: Run OpenLens.exe --disable-gpu --no-sandbox or delete %APPDATA%\OpenLens
kubectl: command not found: winget install Kubernetes.kubectl and reopen PowerShell
Docker Desktop Kubernetes not Ready: Docker Desktop -> Settings -> Kubernetes -> Reset Kubernetes Cluster
k9s shows no pods: kubectl config use-context docker-desktop or minikube
Terraform EKS takes long: Normal, 15-20 mins. Check aws eks list-clusters
EKS costs: Run terraform destroy -auto-approve after test
Next Steps
Replace nginx with your real app:
Change image = "nginx:1.25" to image = "your-ecr/app1:latest"
Build: docker build -t app1 .
Add ArgoCD (GitOps):
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Add Vault + JFrog:
helm install vault hashicorp/vault
helm repo add jfrog https://charts.jfrog.io
helm install artifactory jfrog/artifactory
Add SonarQube scanning to pipeline
Author
Built from whiteboard design -> Implemented with Terraform Modules + Kubernetes + AWS EKS/ECR

Local: Docker Desktop + k9s + FreeLens/OpenLens 6.5.2-366
Cloud: AWS EKS + ECR + VPC + Terraform
For questions: Check kubectl get nodes, kubectl get pods, and terraform output
