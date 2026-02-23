
#Route Tables for Public and Private Subnets

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc["myvpc"].id

  tags = {
    Name = "private_route_table"
  }
}


resource "aws_route_table_association" "private-us-west-2a" {
  subnet_id      = aws_subnet.private_subnet["private_a"].id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private-us-west-2b" {
  subnet_id      = aws_subnet.private_subnet["private_b"].id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private-us-west-2c" {
  subnet_id      = aws_subnet.private_subnet["private_c"].id
  route_table_id = aws_route_table.private_route_table.id
}






resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc["myvpc"].id

  tags = {
    Name = "myvpc-igw"
  }
}

resource "aws_route" "public_default_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc["myvpc"].id

  tags = {
    Name = "public_route_table"
  }
}


#public

resource "aws_route_table_association" "public-us-west-2a" {
  subnet_id      = aws_subnet.public_subnet["public_a"].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public-us-west-2b" {
  subnet_id      = aws_subnet.public_subnet["public_b"].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public-us-west-2c" {
  subnet_id      = aws_subnet.public_subnet["public_c"].id
  route_table_id = aws_route_table.public_route_table.id
} 