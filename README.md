# Incode Infrastructure

Terraform infrastructure for the Incode platform on AWS. Manages VPC, EKS, and RDS across multiple environments.

## Structure

```
infra/
├── prod/                  # Production environment (self-contained)
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── data.tf
│   └── output.tf
├── dev/                   # Development environment (self-contained)
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── data.tf
│   └── output.tf
└── modules/               # Shared modules
    ├── vpc/
    ├── eks/
    └── database/
```

Each environment is fully isolated with its own:
- State file in S3
- DynamoDB lock table
- Provider version pin (`.terraform.lock.hcl`)
- Variable values

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate profile
- S3 bucket `terraform-state-imilosevic` (existing)
- DynamoDB lock tables (see Bootstrap below)

## Bootstrap

Create DynamoDB lock tables once per environment (only needed on first setup):

```bash
# Prod lock table (may already exist)
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

## Usage

Each environment is run independently from its own directory. No `-var-file` or `-backend-config` flags needed.

### Production

```bash
cd infra/prod
terraform init
terraform plan
terraform apply
```

### Dev

```bash
cd infra/dev
terraform init
terraform plan
terraform apply
```

### Teardown

> ⚠️ Production resources have `prevent_destroy = true` on the EKS cluster. (not yet actually)
> You must remove this before destroying prod.

```bash
cd infra/prod   # or infra/dev
terraform destroy
```

## Modules

### VPC (`modules/vpc`)

Creates a VPC with public, app (private), database, and monitoring subnets across multiple AZs. Includes NAT Gateway for private subnet egress.

| Variable | Description | Default |
|----------|-------------|---------|
| `name` | Prefix for all resources | required |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `az_count` | Number of AZs (1-3) | `1` |
| `enable_nat` | Create NAT Gateway | `false` |
| `enable_monitoring` | Create monitoring subnets | `false` |

### EKS (`modules/eks`)

Creates an EKS cluster with a managed node group, IAM roles, security groups, and VPC CNI + Pod Identity addons.

| Variable | Description | Default |
|----------|-------------|---------|
| `name` | Cluster name | required |
| `subnet_ids` | Subnets for nodes | required |
| `node_instance_type` | EC2 instance type | `t3.micro` |
| `node_desired_size` | Desired node count | `2` |
| `node_min_size` | Minimum node count | `1` |
| `node_max_size` | Maximum node count | `4` |

### Database (`modules/database`)

Creates either an RDS PostgreSQL instance or Aurora Serverless v2 cluster with optional read replica in prod.

| Variable | Description | Default |
|----------|-------------|---------|
| `db_engine` | `rds` or `aurora` | `rds` |
| `environment` | Environment name | `dev` |
| `db_username` | Master username | required |
| `db_password` | Master password | required |
| `subnet_group_name` | DB subnet group | required |
| `security_group_ids` | Allowed SGs | required |
| `backup_retention_period` | Days to retain backups (1-35) | `7` |

## Tagging

All resources are automatically tagged via `default_tags` in the provider:

```
env       = "prod" | "dev"
createdBy = "terraform"
```

## State

| Environment | S3 Key | DynamoDB Table |
|-------------|--------|----------------|
| prod | `prod/terraform.tfstate` | `terraform-lock-imilosevic-prod` |
| dev | `dev/terraform.tfstate` | `terraform-lock-imilosevic-dev` |

## Connecting to the Cluster

```bash
aws eks update-kubeconfig \
  --region eu-central-1 \
  --name prod-eks   # or dev-eks

kubectl get nodes
```

## Troubleshooting

**State lock stuck:**
```bash
terraform force-unlock <lock-id>

# If that fails, delete directly from DynamoDB
aws dynamodb delete-item \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-prod \
  --key '{"LockID": {"S": "terraform-state-imilosevic/prod/terraform.tfstate"}}'
```

**State checksum mismatch:**
```bash
aws dynamodb put-item \
  --region eu-central-1 \
  --table-name terraform-lock-imilosevic-prod \
  --item '{
    "LockID": {"S": "terraform-state-imilosevic/prod/terraform.tfstate-md5"},
    "Digest": {"S": "<calculated-checksum>"}
  }'
```

**Nodes not registering:**
- Verify `enable_nat = true` in the VPC module
- Check subnet tags include `kubernetes.io/cluster/<name> = shared`
- Ensure node instance type has sufficient memory (minimum `t3.medium`)