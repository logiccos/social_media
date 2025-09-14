#!/bin/bash

# ========================================
# 🚀 CONFIGURADOR AUTOMÁTICO VIA SSH
# ========================================
# Este script configura o servidor de vídeos
# em um subdomínio seguro sem interferir
# com sites em produção
# ========================================

# Configurações
VPS_USER="root"
VPS_HOST="logiccos.com"
SUBDOMAIN="videos-n8n-7x9k2"

echo "🚀 Iniciando configuração do servidor de vídeos..."
echo "📍 Subdomínio: ${SUBDOMAIN}.${VPS_HOST}"
echo "⚠️  Isso NÃO afetará seus sites em produção!"
echo ""
echo "Digite a senha do servidor quando solicitado..."

# Criar e enviar o script de instalação
cat > /tmp/remote_install.sh << 'REMOTE_SCRIPT'
#!/bin/bash

# ================================================
# 🎬 SERVIDOR DE VÍDEOS PARA N8N - SUBDOMÍNIO
# ================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações do subdomínio
SUBDOMAIN="videos-n8n-7x9k2"
FULL_DOMAIN="${SUBDOMAIN}.logiccos.com"
VIDEO_DIR="/var/www/${SUBDOMAIN}"
API_PORT="5847"  # Porta diferente para não conflitar

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🚀 INSTALANDO SERVIDOR DE VÍDEOS${NC}"
echo -e "${GREEN}📍 Subdomínio: $FULL_DOMAIN${NC}"
echo -e "${GREEN}📁 Diretório: $VIDEO_DIR${NC}"
echo -e "${GREEN}================================================${NC}"

# 1. Atualizar sistema
echo -e "\n${YELLOW}📦 Atualizando sistema...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y nginx python3 python3-pip python3-venv ffmpeg curl > /dev/null 2>&1

# 2. Criar estrutura de pastas
echo -e "${YELLOW}📁 Criando diretórios...${NC}"
mkdir -p $VIDEO_DIR/{upload,processed,temp,logs}
chmod -R 755 $VIDEO_DIR
chown -R www-data:www-data $VIDEO_DIR

# 3. Configurar Python
echo -e "${YELLOW}🐍 Configurando Python...${NC}"
cd /opt
python3 -m venv ${SUBDOMAIN}_env
source /opt/${SUBDOMAIN}_env/bin/activate
pip install -q flask flask-cors werkzeug

# 4. Criar API Flask
echo -e "${YELLOW}⚡ Criando API...${NC}"
cat > /opt/${SUBDOMAIN}_api.py << 'EOF'
import os, json, subprocess, hashlib, time
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# Config
PROCESSED_FOLDER = '/var/www/videos-n8n-7x9k2/processed'
TEMP_FOLDER = '/var/www/videos-n8n-7x9k2/temp'
MAX_FILE_SIZE = 500 * 1024 * 1024
ALLOWED_EXTENSIONS = {'mp4', 'mov', 'avi', 'mkv', 'webm'}
DOMAIN = 'videos-n8n-7x9k2.logiccos.com'

for folder in [PROCESSED_FOLDER, TEMP_FOLDER]:
    os.makedirs(folder, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def generate_unique_filename(original_filename):
    timestamp = str(int(time.time()))
    hash_hex = hashlib.md5(f"{original_filename}{timestamp}".encode()).hexdigest()[:8]
    extension = original_filename.rsplit('.', 1)[1].lower()
    return f"video_{timestamp}_{hash_hex}.{extension}"

def optimize_video(input_path, output_path):
    try:
        cmd = [
            'ffmpeg', '-i', input_path,
            '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
            '-c:a', 'aac', '-b:a', '128k',
            '-vf', "scale='min(1080,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease",
            '-movflags', '+faststart', '-y', output_path
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=180)
        return result.returncode == 0
    except:
        return False

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'domain': DOMAIN}), 200

@app.route('/upload', methods=['POST'])
def upload():
    try:
        if 'video' not in request.files:
            return jsonify({'success': False, 'error': 'No video file'}), 400

        file = request.files['video']
        if file.filename == '' or not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file'}), 400

        file.seek(0, os.SEEK_END)
        if file.tell() > MAX_FILE_SIZE:
            return jsonify({'success': False, 'error': 'File too large'}), 400
        file.seek(0)

        unique_name = generate_unique_filename(file.filename)
        temp_path = os.path.join(TEMP_FOLDER, unique_name)
        file.save(temp_path)

        output_name = unique_name.rsplit('.', 1)[0] + '.mp4'
        output_path = os.path.join(PROCESSED_FOLDER, output_name)

        if optimize_video(temp_path, output_path):
            os.remove(temp_path)
            url = f"http://{DOMAIN}/videos/{output_name}"
            return jsonify({
                'success': True,
                'url': url,
                'filename': output_name
            }), 200
        else:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return jsonify({'success': False, 'error': 'Processing failed'}), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/list', methods=['GET'])
def list_videos():
    try:
        videos = []
        for f in os.listdir(PROCESSED_FOLDER):
            if f.endswith(('.mp4', '.mov', '.avi')):
                videos.append({
                    'filename': f,
                    'url': f"http://{DOMAIN}/videos/{f}"
                })
        return jsonify({'success': True, 'videos': videos}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/delete/<filename>', methods=['DELETE'])
def delete(filename):
    try:
        path = os.path.join(PROCESSED_FOLDER, secure_filename(filename))
        if os.path.exists(path):
            os.remove(path)
            return jsonify({'success': True}), 200
        return jsonify({'success': False, 'error': 'Not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5847)
EOF

# 5. Configurar Nginx
echo -e "${YELLOW}🌐 Configurando Nginx...${NC}"
cat > /etc/nginx/sites-available/${SUBDOMAIN} << EOF
server {
    listen 80;
    server_name ${FULL_DOMAIN};

    client_max_body_size 500M;
    client_body_timeout 300s;

    location /videos/ {
        alias ${VIDEO_DIR}/processed/;
        add_header Cache-Control "public, max-age=31536000";
        add_header Access-Control-Allow-Origin *;

        location ~ \.(mp4|webm|mov|avi)$ {
            mp4;
            mp4_buffer_size 4M;
            mp4_max_buffer_size 10M;
        }
    }

    location / {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;

        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS" always;

        if (\$request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS";
            add_header Content-Length 0;
            add_header Content-Type text/plain;
            return 204;
        }
    }
}
EOF

ln -sf /etc/nginx/sites-available/${SUBDOMAIN} /etc/nginx/sites-enabled/

# 6. Criar serviço systemd
echo -e "${YELLOW}⚙️ Configurando serviço...${NC}"
cat > /etc/systemd/system/${SUBDOMAIN}-api.service << EOF
[Unit]
Description=Video API - ${SUBDOMAIN}
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt
Environment="PATH=/opt/${SUBDOMAIN}_env/bin"
ExecStart=/opt/${SUBDOMAIN}_env/bin/python /opt/${SUBDOMAIN}_api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 7. Iniciar serviços
echo -e "${YELLOW}🔥 Iniciando serviços...${NC}"
systemctl daemon-reload
systemctl start ${SUBDOMAIN}-api
systemctl enable ${SUBDOMAIN}-api > /dev/null 2>&1
nginx -t > /dev/null 2>&1 && systemctl reload nginx

# 8. Criar script de teste
echo -e "${YELLOW}🧪 Criando script de teste...${NC}"
cat > /root/test_video_server.sh << 'TEST'
#!/bin/bash
echo "🧪 Testando servidor de vídeos..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://videos-n8n-7x9k2.logiccos.com/health)
if [ "$response" = "200" ]; then
    echo "✅ Servidor funcionando!"
    curl -s http://videos-n8n-7x9k2.logiccos.com/health | python3 -m json.tool
else
    echo "❌ Erro: HTTP $response"
fi
TEST
chmod +x /root/test_video_server.sh

# Teste final
sleep 3
echo -e "\n${GREEN}================================================${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${API_PORT}/health)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo -e "\n📍 URLs do servidor:"
    echo -e "  🌐 API: ${GREEN}http://${FULL_DOMAIN}${NC}"
    echo -e "  📹 Vídeos: ${GREEN}http://${FULL_DOMAIN}/videos/{filename}${NC}"
    echo -e "\n🔑 Endpoints:"
    echo -e "  POST   ${GREEN}http://${FULL_DOMAIN}/upload${NC}"
    echo -e "  GET    ${GREEN}http://${FULL_DOMAIN}/list${NC}"
    echo -e "  DELETE ${GREEN}http://${FULL_DOMAIN}/delete/{file}${NC}"
    echo -e "  GET    ${GREEN}http://${FULL_DOMAIN}/health${NC}"
    echo -e "\n📝 Teste: ${GREEN}bash /root/test_video_server.sh${NC}"
else
    echo -e "${RED}❌ Erro na instalação. Verifique os logs.${NC}"
    journalctl -u ${SUBDOMAIN}-api -n 20
fi

REMOTE_SCRIPT

# Enviar e executar no servidor
echo "📤 Enviando script para o servidor..."
scp /tmp/remote_install.sh ${VPS_USER}@${VPS_HOST}:/tmp/install_video.sh

echo "🔧 Executando instalação no servidor..."
ssh ${VPS_USER}@${VPS_HOST} "bash /tmp/install_video.sh"

# Limpar arquivo temporário
rm /tmp/remote_install.sh

echo ""
echo "✅ Processo concluído!"
echo ""
echo "📌 CONFIGURAÇÃO DO N8N:"
echo "========================"
echo "URL Base: http://${SUBDOMAIN}.${VPS_HOST}"
echo ""
echo "Node HTTP Request - Upload:"
echo "- Method: POST"
echo "- URL: http://${SUBDOMAIN}.${VPS_HOST}/upload"
echo "- Body Type: Form-Data"
echo "- Field Name: video"
echo ""
echo "🧪 Para testar manualmente:"
echo "curl http://${SUBDOMAIN}.${VPS_HOST}/health"