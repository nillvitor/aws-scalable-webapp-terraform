# Aplicação Web Escalável na AWS com Terraform

Este projeto provisiona uma infraestrutura completa na AWS para hospedar uma aplicação web simples de "contador de cliques". A infraestrutura é projetada para ser escalável, altamente disponível e segura, utilizando as melhores práticas de IaC (Infrastructure as Code) com o Terraform.

## Arquitetura

A arquitetura consiste nos seguintes componentes:

1.  **VPC (Virtual Private Cloud):** Uma rede isolada para hospedar todos os recursos.
2.  **Sub-redes Públicas e Privadas:**
    *   **Públicas:** Duas sub-redes em Zonas de Disponibilidade (AZs) diferentes para hospedar o Application Load Balancer (ALB) e os NAT Gateways.
    *   **Privadas:** Duas sub-redes em AZs diferentes para hospedar as instâncias EC2, garantindo que elas não sejam diretamente acessíveis pela internet.
3.  **Application Load Balancer (ALB):** Distribui o tráfego HTTP de entrada entre as instâncias EC2 nas sub-redes privadas.
4.  **Auto Scaling Group (ASG):** Gerencia o número de instâncias EC2, escalando para mais ou menos instâncias com base na demanda (política de escalonamento não implementada, mas a base está pronta). Garante a alta disponibilidade, substituindo instâncias não saudáveis.
5.  **Launch Template:** Define a configuração das instâncias EC2, incluindo a AMI (Amazon Linux 2023), tipo de instância e o script de `user data`.
6.  **NAT Gateway:** Permite que as instâncias nas sub-redes privadas acessem a internet para atualizações de pacotes, sem permitir conexões de entrada. Um NAT Gateway é provisionado em cada AZ para alta disponibilidade.
7.  **DynamoDB:** Um banco de dados NoSQL totalmente gerenciado, usado para persistir a contagem de cliques. A configuração `PAY_PER_REQUEST` é econômica para cargas de trabalho imprevisíveis.
8.  **IAM Role:** Fornece às instâncias EC2 as permissões necessárias para acessar o DynamoDB e para se conectar via Session Manager (SSM), sem a necessidade de armazenar credenciais de acesso nas instâncias.
9.  **VPC Endpoints:** Permitem que as instâncias EC2 se comuniquem com serviços da AWS (DynamoDB, SSM) usando a rede privada da AWS, o que melhora a segurança e pode reduzir custos de transferência de dados.

```
      Internet
         |
         v
---------------------
| Internet Gateway  |
---------------------
         |
         v
--------------------------------------------------------------------
|                       Application Load Balancer                  |
|                          (Sub-redes Públicas)                    |
--------------------------------------------------------------------
         |
         v
------------------------------------------------------------------------
|                        Auto Scaling Group                            |
|                                                                      |
|  +--------------------+      +--------------------+      +-------+   |
|  | Instância EC2      |      | Instância EC2      | ...  |       |   |
|  | (Sub-rede Privada) |      | (Sub-rede Privada) |      |       |   |
|  +--------------------+      +--------------------+      +-------+   |
|          |                       |                                   |
------------------------------------------------------------------------
           \                     /
            \                   /
             v                 v
     ---------------------------------------
     |         VPC Endpoint para DynamoDB  |
     ---------------------------------------
                      |
                      v
             -------------------
             |   DynamoDB      |
             -------------------
```

## Pré-requisitos

*   Terraform (v1.0+)
*   Uma conta na AWS
*   AWS CLI configurada com credenciais de acesso (`aws configure`)

## Como Usar

1.  **Clone o repositório:**
    ```sh
    git clone https://github.com/nillvitor/aws-scalable-webapp-terraform.git
    cd aws-scalable-webapp-terraform
    ```

2.  **Inicialize o Terraform:**
    Este comando irá baixar os provedores necessários (neste caso, o provedor AWS).
    ```sh
    terraform init
    ```

3.  **Planeje a implantação:**
    Revise os recursos que o Terraform criará.
    ```sh
    terraform plan
    ```

4.  **Aplique a configuração:**
    Provisione todos os recursos na sua conta AWS. Digite `yes` quando solicitado.
    ```sh
    terraform apply
    ```

5.  **Acesse a aplicação:**
    Após a conclusão do `apply`, o Terraform exibirá o DNS do Load Balancer na saída. Copie e cole este endereço no seu navegador.
    ```
    Outputs:

    alb_dns_name = "clickcounter-app-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com"
    ```

## Como Destruir os Recursos

Para remover todos os recursos criados por este projeto e evitar custos, execute:
```sh
terraform destroy
```