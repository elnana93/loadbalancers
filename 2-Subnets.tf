resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnet

  vpc_id            = aws_vpc.vpc["myvpc"].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.is_public

  tags = {
    Name    = "public_subnet-${each.key}"
    Network = "Public"
  }
}


resource "aws_subnet" "private_subnet" {
  for_each = var.private_subnet

  vpc_id            = aws_vpc.vpc["myvpc"].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.is_public

  tags = {
    Name    = "private_subnet-${each.key}"
    Network = "Private"
  }
}

