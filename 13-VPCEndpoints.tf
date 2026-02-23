locals {
  private_subnet_ids = [for k in sort(keys(aws_subnet.private_subnet)) : aws_subnet.private_subnet[k].id]
}

# The trade off to doing it this way is if i need to customize the endpoints later on

locals {
  vpce_services = toset([
    "ssm",
    "ec2messages",
    "ssmmessages",
    "sts",
    "secretsmanager",
    "logs",
    "kms"
  ])
}

resource "aws_vpc_endpoint" "vpce_interface" {
  for_each            = local.vpce_services
  vpc_id              = aws_vpc.vpc["myvpc"].id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [aws_security_group.sg_vpce_lab.id]
  private_dns_enabled = true

  tags = { Name = "vpce-${each.value}" }
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.vpc["myvpc"].id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [
    aws_route_table.private_route_table.id
  ]

  tags = { Name = "vpce-s3-gateway" }
}
