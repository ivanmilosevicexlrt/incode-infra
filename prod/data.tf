data "aws_ssm_parameter" "dbpassword" {
  name            = "/prod/app-1/dbpassword"
  with_decryption = true
}

data "aws_ssm_parameter" "dbuser" {
  name = "/prod/app-1/dbuser"
}