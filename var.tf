variable "region" {
    description = "Provide the region name"
    default = "us-east-1"

}

variable "access_key" {
    description = "access - key for the environment"
    default = ""  
}

variable "secret_key" {
    description = "secret - key for the environment"
    default = ""
  
}

variable "vpc_cidr_block" {
    default = "10.30.0.0/16"
    
}

variable "public_subnet_cidr1" {
    default = "10.30.0.0/24"
    
}

variable "public_subnet_cidr2" {
    default = "10.30.16.0/24"
    
}

variable "private_subnet_cidr" {
    default = "10.30.64.0/24"
    
}

variable "image_id" {
    default = "ami-013f17f36f8b1fefb"
    
}

variable "instance_type" {
    default = "t2.micro"
    
}