# AWS Load Balancer Controller Setup

This guide shows how to configure the AWS Load Balancer Controller for the k8s-gitops repository, which allows using AWS Application Load Balancers for Ingress resources.

## Prerequisites

Before you begin, ensure you have:
- AWS CLI installed and configured
- kubectl configured to access your EKS cluster
- Helm installed
- eksctl installed (for IAM setup)

## 1. IAM Setup for Load Balancer Controller

First, we'll set up the necessary IAM permissions for the Load Balancer Controller to manage AWS resources.

### Create IAM Policy
```bash
# Download the IAM policy document
curl -o terraform/aws/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://terraform/aws/iam-policy.json
```

### Create OIDC Provider for EKS Cluster
```bash
# Get cluster OIDC provider URL
export CLUSTER_NAME=your-cluster-name
export AWS_REGION=your-region
export OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)

# Create OIDC provider
eksctl utils associate-iam-oidc-provider \
    --cluster $CLUSTER_NAME \
    --approve
```

### Create Service Account with IAM Role
```bash
# Get your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create service account with IAM role
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve
```

## 2. Install AWS Load Balancer Controller via Helm

### Add and Update Helm Repository
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

### Install Controller with Helm
```bash
# Get your VPC ID
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$CLUSTER_NAME-vpc" --query "Vpcs[0].VpcId" --output text)

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID
```

### Verify Installation
```bash
# Check if controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## 3. Configure Application for AWS Load Balancer

### Create Application Service Account with IAM Role

Create an IAM policy for the application:

```bash
# Create policy JSON file
cat > terraform/aws/hello-app-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$CLUSTER_NAME-logs/*",
                "arn:aws:s3:::$CLUSTER_NAME-logs"
            ]
        }
    ]
}
EOF

# Create IAM policy
aws iam create-policy \
    --policy-name HelloAppS3Policy \
    --policy-document file://terraform/aws/hello-app-policy.json
```

Create service account in Kubernetes:

```yaml
# Add to apps/dev/hello-app/k8s/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-app-sa
  namespace: hello-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$AWS_ACCOUNT_ID:role/hello-app-role
```

Create IAM role for the application:

```bash
# Create trust policy
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')

cat > terraform/aws/hello-app-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:hello-app:hello-app-sa"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name hello-app-role \
    --assume-role-policy-document file://terraform/aws/hello-app-trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
    --role-name hello-app-role \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/HelloAppS3Policy
```

### Configure Ingress with AWS ALB Annotations

Add this to your application's ingress configuration:

```yaml
# Edit apps/dev/hello-app/k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
  namespace: hello-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/group.name: hello-app
    alb.ingress.kubernetes.io/tags: Environment=dev,Team=platform
spec:
  rules:
  - host: hello-app.your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-app
            port:
              number: 80
```

### Update Application Deployment to Use Service Account

```yaml
# Edit apps/dev/hello-app/k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  namespace: hello-app
spec:
  template:
    metadata:
      labels:
        app: hello-app
    spec:
      serviceAccountName: hello-app-sa
      containers:
      - name: hello-app
        image: tomcroll/hello-app:latest
        env:
        - name: AWS_REGION
          value: ${AWS_REGION}
```

### Add Network Policy for AWS ALB

```yaml
# Add to apps/dev/hello-app/k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hello-app-network-policy
  namespace: hello-app
spec:
  podSelector:
    matchLabels:
      app: hello-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: ${VPC_CIDR}  # Your VPC CIDR
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - ipBlock:
        cidr: ${VPC_CIDR}  # Your VPC CIDR
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

## 4. Terraform Configuration (Alternative Approach)

The repository includes Terraform code to automate AWS Load Balancer Controller setup.

```bash
# Navigate to Terraform directory
cd terraform/aws

# Initialize Terraform
terraform init

# Plan the changes
terraform plan -var="cluster_name=${CLUSTER_NAME}" -var="region=${AWS_REGION}"

# Apply the changes
terraform apply -var="cluster_name=${CLUSTER_NAME}" -var="region=${AWS_REGION}"
```

The Terraform configuration will:
- Create the necessary IAM policies and roles
- Set up OIDC provider integration
- Install AWS Load Balancer Controller using Helm

## 5. Setting Up Certificate for HTTPS

### Create or Import Certificate in AWS Certificate Manager
```bash
# Create certificate request
aws acm request-certificate \
    --domain-name hello-app.your-domain.com \
    --validation-method DNS \
    --region $AWS_REGION
```

### Update Ingress Configuration with Certificate ARN
```yaml
# Update the annotation in apps/dev/hello-app/k8s/ingress.yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:${AWS_REGION}:${AWS_ACCOUNT_ID}:certificate/certificate-id
```

## 6. Monitoring and Logging

### Enable Access Logging to S3
```bash
# Create S3 bucket for logs (if not exists)
aws s3 mb s3://$CLUSTER_NAME-logs --region $AWS_REGION

# Add logging annotation to ingress
annotations:
  alb.ingress.kubernetes.io/load-balancer-attributes: access_logs.s3.enabled=true,access_logs.s3.bucket=${CLUSTER_NAME}-logs,access_logs.s3.prefix=hello-app-logs
```

### Set Up CloudWatch Alarms
```bash
# Create alarm for high 5XX errors
aws cloudwatch put-metric-alarm \
    --alarm-name HelloApp-High5XXCount \
    --alarm-description "Alarm when 5XX errors exceed threshold" \
    --metric-name HTTPCode_Target_5XX_Count \
    --namespace AWS/ApplicationELB \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=app/hello-app/1234567890abcdef \
    --evaluation-periods 1 \
    --alarm-actions arn:aws:sns:$AWS_REGION:$AWS_ACCOUNT_ID:alarms-topic
```

## 7. Best Practices

1. **Security Best Practices**
   - Use private subnets for worker nodes
   - Use security groups to restrict traffic
   - Implement WAF for additional security
   - Regularly rotate IAM credentials

2. **High Availability**
   - Deploy across multiple AZs
   - Use target group health checks with appropriate thresholds
   - Set up cross-zone load balancing for even distribution

3. **Cost Optimization**
   - Use IP mode for better resource utilization
   - Implement auto-scaling based on metrics
   - Monitor and remove unused ALBs
   - Consider using ALB Controller's Shield integration for critical workloads

4. **Monitoring**
   - Set up CloudWatch dashboards for ALB metrics
   - Create alarms for key metrics (5xx errors, latency)
   - Enable access logging for troubleshooting and auditing
   - Integrate with existing monitoring solutions 