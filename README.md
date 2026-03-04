# Incode Infrastructure & Kubernetes Setup Guide

Terraform infrastructure and Kubernetes resource management for the Incode platform on AWS.
Manages VPC, EKS, RDS, ALB, Karpenter, and External Secrets across multiple environments.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Prerequisites](#prerequisites)
3. [Bootstrap](#bootstrap)
4. [Step 1 — Core Infrastructure](#step-1--core-infrastructure)
5. [Step 2 — ALB Controller](#step-2--alb-controller)
6. [Step 3 — Addons (Karpenter + ESO)](#step-3--addons-karpenter--eso)
7. [Step 4 — Kubernetes Resources](#step-4--kubernetes-resources)
   - [ClusterSecretStore + ExternalSecret](#clustersecretstore--externalsecret)
   - [Ingress](#ingress)
8. [Connecting to the Cluster](#connecting-to-the-cluster)
9. [Modules Reference](#modules-reference)
10. [State Reference](#state-reference)
11. [Troubleshooting](#troubleshooting)

---

## Project Structure

```
.
├── infra/
│   ├── prod/                        # Production environment (self-contained)
│   │   ├── main.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   └── output.tf
│   ├── dev/                         # Development environment (self-contained)
│   │   ├── main.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── data.tf
│   │   └── output.tf
│   └── modules/                     # Shared Terraform modules
│       ├── vpc/
│       ├── eks/
│       │   └── addons/              # Karpenter + ESO
│       └── database/
├── alb/                             # ALB Controller (separate state)
│   ├── main.tf
│   ├── data.tf
│   ├── variables.tf
│   ├── provider.tf
│   └── prod.tfvars
└── k8s/                             # Kubernetes manifests
    ├── secret_store.yaml            # ClusterSecretStore + ExternalSecret
    └── ingress.yaml                 # ALB Ingress
```

---

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate profile
- `kubectl`
- `helm`
- S3 bucket `terraform-state-imilosevic` (must exist)
- DynamoDB lock tables (see Bootstrap below)

---

## Bootstrap

Create DynamoDB lock tables once per environment (only needed on first setup):

```bash
# Prod lock table
aws dynamodb create-table \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Dev lock table
aws dynamodb create-table \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Step 1 — Core Infrastructure

Provisions VPC, EKS cluster, OIDC provider, RDS, and all required IAM roles.

```bash
cd infra/prod
terraform init
terraform plan
terraform apply
```

Verify key outputs are available before proceeding:

```bash
terraform output oidc_provider_arn
terraform output cluster_name
terraform output vpc_id
```

---

## Step 2 — ALB Controller

Provisions the AWS Load Balancer Controller IRSA role and Helm release.

```bash
cd alb
terraform init -backend-config=incode.tfbackend
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

Verify:

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get ingressclass
# Expected:
# NAME   CONTROLLER            PARAMETERS   AGE
# alb    ingress.k8s.aws/alb   <none>       ...
```

---

## Step 3 — Addons (Karpenter + ESO)

The addons module is called from root `main.tf` and provisions:
- Karpenter CRD + Helm release in `kube-system`
- IAM role `external-secrets-prod` with IRSA binding
- External Secrets Operator Helm release in `external-secrets` with role ARN injected into the service account

```hcl
# infra/prod/main.tf
module "addons" {
  source             = "../modules/eks/addons"
  cluster_name       = module.eks.cluster_name
  karpenter_version  = "1.9.0"
  eso_version        = "0.10.0"
  karpenter_role_arn = module.eks.karpenter_role_arn
  oidc_provider_arn  = module.eks.oidc_provider_arn
  depends_on         = [null_resource.kubeconfig]
}
```

```bash
cd infra/prod
terraform apply
```

Verify ESO service account has IRSA annotation:

```bash
kubectl describe sa external-secrets -n external-secrets | grep role-arn
# Expected:
# eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/external-secrets-prod
```

---

## Step 4 — Kubernetes Resources

### ClusterSecretStore + ExternalSecret

> **Important:** The secret must exist in AWS Secrets Manager before applying.
> Verify with: `aws secretsmanager get-secret-value --secret-id /prod/app-1/`

**`k8s/secret_store.yaml`**

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: prodclstore
spec:
  provider:
    aws:
      service: SecretsManager        # must match where your secret lives
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials-sec-store
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: prodclstore
    kind: ClusterSecretStore
  target:
    name: db-credentials-sec-store
    creationPolicy: Owner
  data:
    - secretKey: DB_USER
      remoteRef:
        key: /prod/app-1/
        property: username
    - secretKey: DB_PASSWORD
      remoteRef:
        key: /prod/app-1/
        property: password
```

```bash
kubectl apply -f k8s/secret_store.yaml
```

Verify:

```bash
kubectl get clustersecretstore
# Expected: prodclstore   Valid   ReadWrite   True

kubectl get externalsecret -n default
# Expected: STATUS: SecretSynced   READY: True

kubectl get secret db-credentials-sec-store -n default
```

---

### Ingress

> **Important:** Use `ingressClassName: alb` only. Do not mix with the legacy
> annotation `kubernetes.io/ingress.class: nginx` — they conflict and will
> prevent ALB provisioning.

**`k8s/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: incodedemo-api
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: /api/health
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: incodedemo-api
                port:
                  number: 80
```

```bash
kubectl apply -f k8s/ingress.yaml

# Watch for ALB provisioning (takes 2-3 min)
kubectl get ingress -w
# Expected:
# NAME             CLASS   HOSTS   ADDRESS                              PORTS   AGE
# incodedemo-api   alb     *       xxxx.us-east-1.elb.amazonaws.com    80      2m
```

---

## Connecting to the Cluster

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name prod-eks

kubectl get nodes
```

---

## Modules Reference

### VPC (`modules/vpc`)

| Variable | Description | Default |
|----------|-------------|---------|
| `name` | Prefix for all resources | required |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `az_count` | Number of AZs (1-3) | `1` |
| `enable_nat` | Create NAT Gateway | `false` |
| `enable_monitoring` | Create monitoring subnets | `false` |

### EKS (`modules/eks`)

| Variable | Description | Default |
|----------|-------------|---------|
| `name` | Cluster name | required |
| `subnet_ids` | Subnets for nodes | required |
| `node_instance_type` | EC2 instance type | `t3.micro` |
| `node_desired_size` | Desired node count | `2` |
| `node_min_size` | Minimum node count | `1` |
| `node_max_size` | Maximum node count | `4` |

### EKS Addons (`modules/eks/addons`)

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name | required |
| `oidc_provider_arn` | OIDC provider ARN for IRSA | required |
| `karpenter_version` | Karpenter Helm chart version | `1.9.0` |
| `karpenter_role_arn` | IAM role ARN for Karpenter | required |
| `eso_version` | ESO Helm chart version | `0.10.0` |

### Database (`modules/database`)

| Variable | Description | Default |
|----------|-------------|---------|
| `db_engine` | `rds` or `aurora` | `rds` |
| `environment` | Environment name | `dev` |
| `db_username` | Master username | required |
| `db_password` | Master password | required |
| `subnet_group_name` | DB subnet group | required |
| `security_group_ids` | Allowed SGs | required |
| `backup_retention_period` | Days to retain backups (1-35) | `7` |

---

## State Reference

| Component | S3 Key | DynamoDB Table |
|-----------|--------|----------------|
| prod infra | `prod/terraform.tfstate` | `terraform-lock-imilosevic-prod` |
| dev infra | `dev/terraform.tfstate` | `terraform-lock-imilosevic-dev` |
| alb | separate backend | `incode.tfbackend` |

---

## Troubleshooting

### ExternalSecret stuck in SecretSyncedError

```bash
# 1. Check IRSA annotation
kubectl describe sa external-secrets -n external-secrets | grep role-arn

# 2. Verify secret exists in AWS at correct path
aws secretsmanager get-secret-value --secret-id /prod/app-1/

# 3. Confirm ClusterSecretStore uses SecretsManager not ParameterStore
kubectl describe clustersecretstore prodclstore

# 4. Check ESO logs
kubectl logs -n external-secrets deployment/external-secrets
```

### Ingress has no ADDRESS

```bash
# 1. Confirm ingressClassName is alb
kubectl get ingress

# 2. Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# 3. Verify subnet tags in AWS
# Required tags on public subnets:
# kubernetes.io/role/elb = 1
# kubernetes.io/cluster/<cluster-name> = shared
```

### State lock stuck

```bash
terraform force-unlock <lock-id>

# If that fails, delete directly from DynamoDB
aws dynamodb delete-item \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-prod \
  --key '{"LockID": {"S": "terraform-state-imilosevic/prod/terraform.tfstate"}}'
```

### State checksum mismatch

```bash
aws dynamodb put-item \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-prod \
  --item '{
    "LockID": {"S": "terraform-state-imilosevic/prod/terraform.tfstate-md5"},
    "Digest": {"S": "<calculated-checksum>"}
  }'
```

### Nodes not registering

- Verify `enable_nat = true` in the VPC module
- Check subnet tags include `kubernetes.io/cluster/<name> = shared`
- Ensure node instance type has sufficient memory (minimum `t3.medium`)

---

## Expected Final State

```
✅ EKS cluster running
✅ ALB IngressClass registered (alb)
✅ Karpenter running in kube-system
✅ ESO running in external-secrets
✅ SA external-secrets annotated with IRSA role ARN
✅ ClusterSecretStore prodclstore: Valid
✅ ExternalSecret db-credentials-sec-store: SecretSynced
✅ K8s Secret db-credentials-sec-store created in default
✅ Ingress ADDRESS populated with ALB DNS
```
