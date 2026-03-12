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

# ─── FLUENT BIT ───────────────────────────────────────────────────────────────

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

    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "monitoring"
        effect: "NoSchedule"

    nodeSelector:
      dedicated: "monitoring"

    config:
      outputs: |
        [OUTPUT]
            Name              cloudwatch_logs
            Match             *
            region            ${data.aws_region.current.name}
            log_group_name    /eks/${var.cluster_name}
            log_stream_prefix fluent-bit-
            auto_create_group true
    EOT
  ]

  depends_on = [module.fluent_bit_irsa]
}

# ─── GRAFANA ──────────────────────────────────────────────────────────────────

module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name = "grafana-${var.cluster_name}"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["monitoring:grafana"]
    }
  }

  role_policy_arns = {
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  }
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "monitoring"
  create_namespace = true
  version          = "8.3.6"

  values = [
    <<-EOT
    serviceAccount:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: ${module.grafana_irsa.iam_role_arn}

    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "monitoring"
        effect: "NoSchedule"

    nodeSelector:
      dedicated: "monitoring"

    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
          - name: CloudWatch
            type: cloudwatch
            access: proxy
            uid: cloudwatch
            jsonData:
              authType: default
              defaultRegion: ${data.aws_region.current.name}
              logGroups:
                - arn: arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.cluster_name}
            isDefault: true

    persistence:
      enabled: true
      size: 5Gi

    admin:
      existingSecret: grafana-admin-secret
      userKey: admin-user
      passwordKey: admin-password
    EOT
  ]

  depends_on = [module.grafana_irsa]
}

module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name = "grafana-${var.cluster_name}"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["monitoring:grafana"]
    }
  }

  role_policy_arns = {
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  }
}

resource "kubernetes_manifest" "grafana_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "grafana-admin-secret"
      namespace = "monitoring"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-secrets-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "grafana-admin-secret"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "/dev/grafana/"
          }
        }
      ]
    }
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_manifest.cluster_secret_store
  ]
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "monitoring"
  create_namespace = true
  version          = "8.3.6"

  values = [
    <<-EOT
    serviceAccount:
      create: true
      annotations:
        eks.amazonaws.com/role-arn: ${module.grafana_irsa.iam_role_arn}

    tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "monitoring"
        effect: "NoSchedule"

    nodeSelector:
      dedicated: "monitoring"

    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
          - name: CloudWatch
            type: cloudwatch
            access: proxy
            uid: cloudwatch
            jsonData:
              authType: default
              defaultRegion: ${data.aws_region.current.name}
              logGroups:
                - arn: arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.cluster_name}
            isDefault: true

    persistence:
      enabled: true
      size: 5Gi

    admin:
      existingSecret: grafana-admin-secret
      userKey: admin-user
      passwordKey: admin-password
    EOT
  ]

  depends_on = [
    module.grafana_irsa,
    kubernetes_manifest.grafana_external_secret
  ]
}

# resource "aws_cloudwatch_log_group" "eks" {
#   name              = "/eks/${var.cluster_name}"
#   retention_in_days = 30
# }