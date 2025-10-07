resource "aws_dynamodb_table" "click_counter" {
  name         = "ClickCounterApp" # Mesmo nome usado no script
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "counterId"

  attribute {
    name = "counterId"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-dynamodb-table"
  }
}
