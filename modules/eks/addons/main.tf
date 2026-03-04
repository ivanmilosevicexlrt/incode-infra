resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_version
  namespace        = "kube-system"
  create_namespace = false
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  namespace        = "kube-system"
  create_namespace = false

  values = [
    yamlencode({
      serviceAccount = {
        create = true
      }
      settings = {
        clusterName       = var.cluster_name
        interruptionQueue = var.cluster_name
      }
    })
  ]

  depends_on = [helm_release.karpenter_crd]
}


module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                           = "external-secrets-prod"
  attach_external_secrets_policy      = true
  external_secrets_ssm_parameter_arns = ["arn:aws:ssm:us-east-1:*:parameter/prod/incodedemo/*"]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_version
  namespace        = "external-secrets"
  create_namespace = true

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_secrets_irsa.iam_role_arn
    }
  ]

  depends_on = [module.external_secrets_irsa]
}

module "fluent_bit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name = "fluent-bit-${var.cluster_name}"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["logging:fluent-bit"]
    }
  }

  role_policy_arns = {
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
}


resource "helm_release" "fluent_bit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = "logging"
  create_namespace = true
  version          = "0.46.7"

  values = [
    <<-EOT
    serviceAccount:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: ${module.fluent_bit_irsa.iam_role_arn}
    config:
      outputs: |
        [OUTPUT]
            Name              cloudwatch_logs
            Match             *
            region            us-east-1
            log_group_name    /eks/${var.cluster_name}
            log_stream_prefix fluent-bit-
            auto_create_group true
    EOT
  ]

  depends_on = [module.fluent_bit_irsa]
}

# resource "aws_cloudwatch_log_group" "eks" {
#   name              = "/eks/${var.cluster_name}"
#   retention_in_days = 30
# }