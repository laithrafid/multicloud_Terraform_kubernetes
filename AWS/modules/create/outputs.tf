output "id" {
  value     = aws_iam_access_key.kops.id
  sensitive = true
}
output "secret" {
  value     = aws_iam_access_key.kops.secret
  sensitive = true
}
output "name_servers" {
  value = aws_route53_zone.dns_zone.name_servers
}