#!/bin/bash
# Atualiza os pacotes e instala dependencias
dnf update -y
dnf install python3-pip -y

# Cria o diretório da aplicação e navega para ele
mkdir /app
cd /app

# Cria o arquivo do requirements
cat <<EOF > requirements.txt
Flask
boto3
flask-cors
EOF

# Instala as dependências do Python
pip3 install -r requirements.txt

# Cria o subdiretório para os arquivos estáticos
mkdir static

# Cria o arquivo do servidor Python - a região é passada pelo template
cat <<EOF > server.py
import os
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import boto3

app = Flask(__name__, static_folder='static')
CORS(app)

AWS_REGION = "${aws_region}" # Região injetada pelo Terraform
DYNAMODB_TABLE_NAME = "ClickCounterApp"
COUNTER_ID = "total_clicks"

dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE_NAME)

def get_click_count():
    try:
        response = table.get_item(Key={'counterId': COUNTER_ID})
        if 'Item' in response:
            return int(response['Item']['clickCount'])
        else:
            table.put_item(Item={'counterId': COUNTER_ID, 'clickCount': 0})
            return 0
    except Exception as e:
        print(f"Erro ao buscar contagem: {e}")
        return -1

def increment_click_count():
    try:
        response = table.update_item(
            Key={'counterId': COUNTER_ID},
            UpdateExpression="SET clickCount = if_not_exists(clickCount, :start) + :inc",
            ExpressionAttributeValues={':inc': 1, ':start': 0},
            ReturnValues="UPDATED_NEW"
        )
        return int(response['Attributes']['clickCount'])
    except Exception as e:
        print(f"Erro ao incrementar contagem: {e}")
        return -1

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/api/clicks', methods=['GET'])
def get_clicks():
    count = get_click_count()
    return jsonify(total_clicks=count)

@app.route('/api/click', methods=['POST'])
def record_click():
    new_count = increment_click_count()
    return jsonify(total_clicks=new_count)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF

# Cria o arquivo HTML
cat <<EOF > static/index.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Contador de Cliques IaC</title>
    <style>
        body { display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; font-family: sans-serif; transition: background-color 0.5s ease; text-align: center; }
        .container { padding: 40px; background-color: rgba(255, 255, 255, 0.8); border-radius: 15px; box-shadow: 0 4px 15px rgba(0,0,0,0.2); }
        button { padding: 20px 40px; font-size: 24px; cursor: pointer; border-radius: 10px; border: none; background-color: #007bff; color: white; transition: transform 0.1s ease; }
        button:active { transform: scale(0.95); }
        h1 { font-size: 48px; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Total de Cliques: <span id="counter">Carregando...</span></h1>
        <button id="clickButton">Clique Aqui!</button>
    </div>
    <script>
        const counterElement = document.getElementById('counter');
        const clickButton = document.getElementById('clickButton');
        const body = document.body;
        const API_URL = '';
        function getRandomColor() { const letters = '0123456789ABCDEF'; let color = '#'; for (let i = 0; i < 6; i++) { color += letters[Math.floor(Math.random() * 16)]; } return color; }
        async function fetchInitialCount() { try { const response = await fetch('/api/clicks'); const data = await response.json(); counterElement.textContent = data.total_clicks; } catch (error) { counterElement.textContent = "Erro!"; console.error('Erro ao buscar contagem:', error); } }
        clickButton.addEventListener('click', async () => { try { const response = await fetch('/api/click', { method: 'POST' }); const data = await response.json(); counterElement.textContent = data.total_clicks; body.style.backgroundColor = getRandomColor(); } catch (error) { console.error('Erro ao registrar clique:', error); } });
        document.addEventListener('DOMContentLoaded', () => { fetchInitialCount(); body.style.backgroundColor = getRandomColor(); });
    </script>
</body>
</html>
EOF

# Inicia o servidor em background
nohup python3 /app/server.py > /app/app.log 2>&1 &
