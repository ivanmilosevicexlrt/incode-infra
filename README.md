# Prod
terraform init -reconfigure -backend-config="envs/prod.backend.hcl"
terraform plan -var-file="envs/prod.tfvars"
terraform apply -var-file="envs/prod.tfvars"

# Dev
terraform init -reconfigure -backend-config="envs/dev.backend.hcl"
terraform plan -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"