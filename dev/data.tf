data "aws_ssm_parameter" "dbpassword" {
  name            = "/dev/app-1/dbpassword"
  with_decryption = true
}

data "aws_ssm_parameter" "dbuser" {
  name = "/dev/app-1/dbuser"
}
