data "aws_secretsmanager_secret" "db_creds" {
  name = "/prod/app-1/"
}

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = data.aws_secretsmanager_secret.db_creds.id
}