variable "aws_region" {
  description = "Região da AWS para provisionar os recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base para ser usado nos recursos"
  type        = string
  default     = "clickcounter-app"
}

variable "instance_type" {
  description = "Tipo da instância EC2 para a aplicação"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Número mínimo de instâncias no ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Número máximo de instâncias no ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Número desejado de instâncias no ASG"
  type        = number
  default     = 2
}
