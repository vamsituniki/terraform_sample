output "vpc_id" {
    value = aws_vpc.main.id 
}

output "private_subnet" {
    value = aws_subnet.private-subnet.id
}

output "public_subnet" {
    value = aws_subnet.public-subnet-1.id 
}

