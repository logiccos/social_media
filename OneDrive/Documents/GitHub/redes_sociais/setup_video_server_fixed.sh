#!/bin/bash

# ========================================
# 🚀 CONFIGURADOR COM DADOS PERSONALIZADOS
# ========================================

echo "🔧 CONFIGURAÇÃO DO SERVIDOR DE VÍDEOS"
echo "====================================="
echo ""

# Solicitar informações do servidor
read -p "📍 Digite o IP ou domínio do servidor SSH: " VPS_HOST
read -p "👤 Digite o usuário SSH (padrão: root): " VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "🔌 Digite a porta SSH (padrão: 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

SUBDOMAIN="videos-n8n-7x9k2"

echo ""
echo "📋 Configuração:"
echo "  Servidor: $VPS_HOST"
echo "  Usuário: $VPS_USER"
echo "  Porta: $SSH_PORT"
echo "  Subdomínio: ${SUBDOMAIN}.logiccos.com"
echo ""
read -p "Continuar? (s/n): " confirm

if [ "$confirm" != "s" ]; then
    echo "❌ Cancelado"
    exit 1
fi

# Testar conexão primeiro
echo "🔍 Testando conexão SSH..."
ssh -p $SSH_PORT -o ConnectTimeout=5 ${VPS_USER}@${VPS_HOST} "echo '✅ Conexão OK'" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Não foi possível conectar. Verifique:"
    echo "   - O IP/domínio está correto?"
    echo "   - A porta SSH está correta?"
    echo "   - O firewall permite SSH?"
    echo ""
    echo "🔧 Tente testar manualmente:"
    echo "   ssh -p $SSH_PORT ${VPS_USER}@${VPS_HOST}"
    exit 1
fi

echo "✅ Conexão SSH funcionando!"
echo ""
echo "📤 Preparando instalação..."

# Criar script remoto
cat > /tmp/install_video.sh << 'SCRIPT'
#!/bin/bash

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SUBDOMAIN="videos-n8n-7x9k2"
FULL_DOMAIN="${SUBDOMAIN}.logiccos.com"
VIDEO_DIR="/var/www/${SUBDOMAIN}"
API_PORT="5847"

echo -e "${GREEN}🚀 INSTALANDO SERVIDOR DE VÍDEOS${NC}"
echo -e "📍 Subdomínio: $FULL_DOMAIN"

# Instalar dependências
echo -e "${YELLOW}📦 Instalando dependências...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y nginx python3 python3-pip python3-venv ffmpeg curl > /dev/null 2>&1

# Criar diretórios
echo -e "${YELLOW}📁 Criando diretórios...${NC}"
mkdir -p $VIDEO_DIR/{upload,processed,temp,logs}
chmod -R 755 $VIDEO_DIR
chown -R www-data:www-data $VIDEO_DIR

# Python environment
echo -e "${YELLOW}🐍 Configurando Python...${NC}"
cd /opt
python3 -m venv ${SUBDOMAIN}_env
source /opt/${SUBDOMAIN}_env/bin/activate
pip install -q flask flask-cors werkzeug

# API Flask
echo -e "${YELLOW}⚡ Criando API...${NC}"
cat > /opt/${SUBDOMAIN}_api.py << 'EOF'
import os, json, subprocess, hashlib, time
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

PROCESSED_FOLDER = '/var/www/videos-n8n-7x9k2/processed'
TEMP_FOLDER = '/var/www/videos-n8n-7x9k2/temp'
MAX_FILE_SIZE = 500 * 1024 * 1024
ALLOWED_EXTENSIONS = {'mp4', 'mov', 'avi', 'mkv', 'webm'}
DOMAIN = 'videos-n8n-7x9k2.logiccos.com'

os.makedirs(PROCESSED_FOLDER, exist_ok=True)
os.makedirs(TEMP_FOLDER, exist_ok=True)

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
    return jsonify({'status': 'ok', 'service': 'Video API', 'domain': DOMAIN}), 200

@app.route('/upload', methods=['POST'])
def upload():
    try:
        if 'video' not in request.files:
            return jsonify({'success': False, 'error': 'No video file'}), 400

        file = request.files['video']
        if not file or file.filename == '' or not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Invalid file'}), 400

        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)

        if file_size > MAX_FILE_SIZE:
            return jsonify({'success': False, 'error': f'File too large. Max: {MAX_FILE_SIZE/(1024*1024)}MB'}), 400

        unique_name = generate_unique_filename(file.filename)
        temp_path = os.path.join(TEMP_FOLDER, unique_name)
        file.save(temp_path)

        output_name = unique_name.rsplit('.', 1)[0] + '.mp4'
        output_path = os.path.join(PROCESSED_FOLDER, output_name)

        if optimize_video(temp_path, output_path):
            os.remove(temp_path)
            return jsonify({
                'success': True,
                'url': f"http://{DOMAIN}/videos/{output_name}",
                'filename': output_name,
                'message': 'Video uploaded and optimized successfully'
            }), 200
        else:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return jsonify({'success': False, 'error': 'Video processing failed'}), 500

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
        return jsonify({'success': True, 'count': len(videos), 'videos': videos}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/delete/<filename>', methods=['DELETE'])
def delete(filename):
    try:
        path = os.path.join(PROCESSED_FOLDER, secure_filename(filename))
        if os.path.exists(path):
            os.remove(path)
            return jsonify({'success': True, 'message': f'{filename} deleted'}), 200
        return jsonify({'success': False, 'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        'service': 'Video Hosting API',
        'endpoints': {
            'upload': f'POST http://{DOMAIN}/upload',
            'list': f'GET http://{DOMAIN}/list',
            'delete': f'DELETE http://{DOMAIN}/delete/{{filename}}',
            'health': f'GET http://{DOMAIN}/health'
        },
        'limits': {
            'max_size': '500MB',
            'formats': list(ALLOWED_EXTENSIONS)
        }
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5847)
EOF

# Nginx config
echo -e "${YELLOW}🌐 Configurando Nginx...${NC}"
cat > /etc/nginx/sites-available/${SUBDOMAIN} << EOF
server {
    listen 80;
    server_name ${FULL_DOMAIN};

    client_max_body_size 500M;
    client_body_timeout 300s;
    proxy_read_timeout 300s;

    location /videos/ {
        alias ${VIDEO_DIR}/processed/;
        add_header Cache-Control "public, max-age=31536000";
        add_header Access-Control-Allow-Origin *;
    }

    location / {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;

        # CORS
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS" always;

        if (\$request_method = OPTIONS) {
            return 204;
        }
    }
}
EOF

ln -sf /etc/nginx/sites-available/${SUBDOMAIN} /etc/nginx/sites-enabled/

# Systemd service
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
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start services
echo -e "${YELLOW}🔥 Iniciando serviços...${NC}"
systemctl daemon-reload
systemctl start ${SUBDOMAIN}-api
systemctl enable ${SUBDOMAIN}-api > /dev/null 2>&1
nginx -t > /dev/null 2>&1 && systemctl reload nginx

# Test
sleep 3
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${API_PORT}/health)
if [ "$response" = "200" ]; then
    echo -e "\n${GREEN}✅ INSTALAÇÃO CONCLUÍDA!${NC}"
    echo -e "\n📍 URLs:"
    echo -e "  API: ${GREEN}http://${FULL_DOMAIN}${NC}"
    echo -e "  Upload: ${GREEN}http://${FULL_DOMAIN}/upload${NC}"
    echo -e "  List: ${GREEN}http://${FULL_DOMAIN}/list${NC}"
    echo -e "  Health: ${GREEN}http://${FULL_DOMAIN}/health${NC}"
else
    echo -e "⚠️ API não respondeu. Verificando logs..."
    journalctl -u ${SUBDOMAIN}-api -n 10 --no-pager
fi
SCRIPT

# Enviar e executar
echo "📤 Enviando script..."
scp -P $SSH_PORT /tmp/install_video.sh ${VPS_USER}@${VPS_HOST}:/tmp/

echo "🚀 Executando instalação..."
ssh -p $SSH_PORT ${VPS_USER}@${VPS_HOST} "bash /tmp/install_video.sh"

# Cleanup
rm /tmp/install_video.sh

echo ""
echo "======================================="
echo "✅ CONFIGURAÇÃO FINALIZADA!"
echo "======================================="
echo ""
echo "📌 URLS DO SERVIDOR:"
echo "  http://videos-n8n-7x9k2.logiccos.com"
echo ""
echo "🎯 CONFIGURAÇÃO N8N:"
echo "  Method: POST"
echo "  URL: http://videos-n8n-7x9k2.logiccos.com/upload"
echo "  Body: Form-Data"
echo "  Field: video (binary)"
echo ""
echo "🧪 TESTAR:"
echo "  curl http://videos-n8n-7x9k2.logiccos.com/health"