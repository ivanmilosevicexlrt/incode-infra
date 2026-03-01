output "karpenter_version" {
  description = "Installed Karpenter version"
  value       = helm_release.karpenter.version
}

output "eso_version" {
  description = "Installed ESO version"
  value       = helm_release.external_secrets.version
}
