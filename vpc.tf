# --- Bloco de Dados para buscar as Zonas de Disponibilidade dinamicamente ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# --- Sub-redes Públicas ---
resource "aws_subnet" "public" {
  count                   = 2 # Criar 2 sub-redes públicas
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${100 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# --- Sub-redes Privadas ---
resource "aws_subnet" "private" {
  count             = 2 # Criar 2 sub-redes privadas
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- Tabela de Rota Pública ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- NAT Gateway e Rotas Privadas (Configuração de Alta Disponibilidade) ---
### MUDANÇA ### - Criar 2 Elastic IPs, um para cada NAT Gateway
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
}

### MUDANÇA ### - Criar 2 NAT Gateways, um em cada sub-rede pública
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.main]
}

### MUDANÇA ### - Criar 2 tabelas de rota privadas, uma para cada AZ
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  # A tabela de rota [0] aponta para o NAT Gateway [0], a [1] para o [1], etc.
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

### MUDANÇA ### - Associar cada sub-rede privada à sua respectiva tabela de rota
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- VPC Endpoints para o SSM (Session Manager) ---
# Nenhuma mudança aqui, mas eles continuarão a funcionar como esperado.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
