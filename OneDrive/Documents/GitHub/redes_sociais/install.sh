#!/bin/bash

# ================================================
# 🚀 SERVIDOR DE HOSPEDAGEM DE VÍDEOS PARA N8N
# ================================================
# Domínio: logiccos.com
# Compatível com: Ubuntu/Debian
# Autor: Script Automatizado
# ================================================

set -e  # Para se houver erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis globais
DOMAIN="logiccos.com"
VIDEO_DIR="/var/www/videos"
API_PORT="5000"
NGINX_PORT="80"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🚀 INICIANDO INSTALAÇÃO DO SERVIDOR DE VÍDEOS${NC}"
echo -e "${GREEN}📍 Domínio: $DOMAIN${NC}"
echo -e "${GREEN}================================================${NC}"

# ================================================
# 1️⃣ ATUALIZAÇÃO DO SISTEMA
# ================================================
echo -e "\n${YELLOW}1️⃣ Atualizando sistema...${NC}"
apt-get update -y
apt-get upgrade -y

# ================================================
# 2️⃣ INSTALAÇÃO DE DEPENDÊNCIAS
# ================================================
echo -e "\n${YELLOW}2️⃣ Instalando dependências...${NC}"
apt-get install -y \
    nginx \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    git \
    curl \
    htop \
    ufw \
    supervisor

# ================================================
# 3️⃣ CRIAÇÃO DA ESTRUTURA DE PASTAS
# ================================================
echo -e "\n${YELLOW}3️⃣ Criando estrutura de pastas...${NC}"
mkdir -p $VIDEO_DIR/{upload,processed,temp,logs}
chmod -R 755 $VIDEO_DIR
chown -R www-data:www-data $VIDEO_DIR

# ================================================
# 4️⃣ CRIAÇÃO DO AMBIENTE VIRTUAL PYTHON
# ================================================
echo -e "\n${YELLOW}4️⃣ Configurando ambiente Python...${NC}"
cd /opt
python3 -m venv video_api_env
source /opt/video_api_env/bin/activate
pip install --upgrade pip
pip install flask flask-cors werkzeug

# ================================================
# 5️⃣ CRIAÇÃO DA API PYTHON/FLASK
# ================================================
echo -e "\n${YELLOW}5️⃣ Criando API Flask...${NC}"
cat > /opt/video_api.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
API de Hospedagem de Vídeos para N8N
Processa e otimiza vídeos para Instagram
"""

import os
import json
import subprocess
import hashlib
import time
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename
import logging
from logging.handlers import RotatingFileHandler

# ================================================
# CONFIGURAÇÕES
# ================================================
app = Flask(__name__)
CORS(app)  # Habilita CORS para todas as rotas

# Configurações de upload
UPLOAD_FOLDER = '/var/www/videos/upload'
PROCESSED_FOLDER = '/var/www/videos/processed'
TEMP_FOLDER = '/var/www/videos/temp'
LOG_FOLDER = '/var/www/videos/logs'
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB
ALLOWED_EXTENSIONS = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'}
DOMAIN = 'logiccos.com'

# Criar pastas se não existirem
for folder in [UPLOAD_FOLDER, PROCESSED_FOLDER, TEMP_FOLDER, LOG_FOLDER]:
    os.makedirs(folder, exist_ok=True)

# ================================================
# CONFIGURAÇÃO DE LOGS
# ================================================
if not app.debug:
    file_handler = RotatingFileHandler(
        os.path.join(LOG_FOLDER, 'api.log'),
        maxBytes=10240000,
        backupCount=10
    )
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
    ))
    file_handler.setLevel(logging.INFO)
    app.logger.addHandler(file_handler)
    app.logger.setLevel(logging.INFO)
    app.logger.info('🚀 API de Vídeos iniciada')

# ================================================
# FUNÇÕES AUXILIARES
# ================================================

def allowed_file(filename):
    """Verifica se a extensão do arquivo é permitida"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def generate_unique_filename(original_filename):
    """Gera um nome único para o arquivo"""
    timestamp = str(int(time.time()))
    hash_object = hashlib.md5(f"{original_filename}{timestamp}".encode())
    hash_hex = hash_object.hexdigest()[:8]
    extension = original_filename.rsplit('.', 1)[1].lower()
    return f"video_{timestamp}_{hash_hex}.{extension}"

def optimize_video_for_instagram(input_path, output_path):
    """
    Otimiza vídeo para Instagram usando FFmpeg
    - Codec: H.264
    - Audio: AAC
    - Resolução máxima: 1080p
    - Taxa de bits otimizada
    """
    try:
        # Comando FFmpeg para otimização
        cmd = [
            'ffmpeg',
            '-i', input_path,
            '-c:v', 'libx264',  # Codec de vídeo H.264
            '-preset', 'medium',  # Preset de velocidade/qualidade
            '-crf', '23',  # Qualidade (menor = melhor, 23 é bom para Instagram)
            '-c:a', 'aac',  # Codec de áudio AAC
            '-b:a', '128k',  # Bitrate de áudio
            '-movflags', '+faststart',  # Otimização para streaming
            '-vf', 'scale=\'min(1080,iw)\':\'min(1080,ih)\':force_original_aspect_ratio=decrease',  # Max 1080p
            '-r', '30',  # Frame rate máximo de 30fps
            '-max_muxing_queue_size', '9999',
            '-y',  # Sobrescrever arquivo de saída
            output_path
        ]

        # Executar FFmpeg
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

        if result.returncode == 0:
            app.logger.info(f'✅ Vídeo otimizado: {output_path}')
            return True
        else:
            app.logger.error(f'❌ Erro no FFmpeg: {result.stderr}')
            return False

    except subprocess.TimeoutExpired:
        app.logger.error('❌ Timeout na otimização do vídeo')
        return False
    except Exception as e:
        app.logger.error(f'❌ Erro ao otimizar vídeo: {str(e)}')
        return False

def get_video_info(file_path):
    """Obtém informações do vídeo usando FFprobe"""
    try:
        cmd = [
            'ffprobe',
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            file_path
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            info = json.loads(result.stdout)
            duration = float(info.get('format', {}).get('duration', 0))
            size = int(info.get('format', {}).get('size', 0))

            # Buscar informações de vídeo
            video_stream = next((s for s in info.get('streams', []) if s['codec_type'] == 'video'), {})
            width = video_stream.get('width', 0)
            height = video_stream.get('height', 0)

            return {
                'duration': round(duration, 2),
                'size_mb': round(size / (1024 * 1024), 2),
                'resolution': f"{width}x{height}" if width and height else "unknown"
            }
    except Exception as e:
        app.logger.error(f'❌ Erro ao obter info do vídeo: {str(e)}')

    return {'duration': 0, 'size_mb': 0, 'resolution': 'unknown'}

# ================================================
# ROTAS DA API
# ================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de health check"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'Video Hosting API',
        'domain': DOMAIN
    }), 200

@app.route('/upload', methods=['POST'])
def upload_video():
    """
    Endpoint para upload de vídeos
    Recebe arquivo via POST, otimiza para Instagram e retorna URL pública
    """
    try:
        # Verificar se arquivo foi enviado
        if 'video' not in request.files:
            return jsonify({
                'success': False,
                'error': 'Nenhum arquivo enviado. Use o campo "video"'
            }), 400

        file = request.files['video']

        # Verificar se arquivo foi selecionado
        if file.filename == '':
            return jsonify({
                'success': False,
                'error': 'Nenhum arquivo selecionado'
            }), 400

        # Verificar extensão
        if not allowed_file(file.filename):
            return jsonify({
                'success': False,
                'error': f'Formato não permitido. Use: {", ".join(ALLOWED_EXTENSIONS)}'
            }), 400

        # Verificar tamanho
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)

        if file_size > MAX_FILE_SIZE:
            return jsonify({
                'success': False,
                'error': f'Arquivo muito grande. Máximo: {MAX_FILE_SIZE / (1024*1024)}MB'
            }), 400

        # Gerar nome único
        unique_filename = generate_unique_filename(file.filename)
        temp_path = os.path.join(TEMP_FOLDER, unique_filename)

        # Salvar arquivo temporário
        file.save(temp_path)
        app.logger.info(f'📁 Arquivo salvo temporariamente: {temp_path}')

        # Nome do arquivo processado (sempre .mp4)
        processed_filename = unique_filename.rsplit('.', 1)[0] + '.mp4'
        processed_path = os.path.join(PROCESSED_FOLDER, processed_filename)

        # Otimizar vídeo para Instagram
        app.logger.info(f'🔄 Iniciando otimização do vídeo...')
        if optimize_video_for_instagram(temp_path, processed_path):
            # Remover arquivo temporário
            os.remove(temp_path)

            # Obter informações do vídeo
            video_info = get_video_info(processed_path)

            # Gerar URL pública
            public_url = f"http://{DOMAIN}/videos/{processed_filename}"

            app.logger.info(f'✅ Upload concluído: {public_url}')

            return jsonify({
                'success': True,
                'message': 'Vídeo enviado e otimizado com sucesso',
                'data': {
                    'filename': processed_filename,
                    'url': public_url,
                    'size_mb': video_info['size_mb'],
                    'duration': video_info['duration'],
                    'resolution': video_info['resolution'],
                    'optimized_for': 'Instagram',
                    'timestamp': datetime.now().isoformat()
                }
            }), 200
        else:
            # Limpar arquivos em caso de erro
            if os.path.exists(temp_path):
                os.remove(temp_path)

            return jsonify({
                'success': False,
                'error': 'Erro ao otimizar vídeo'
            }), 500

    except Exception as e:
        app.logger.error(f'❌ Erro no upload: {str(e)}')
        return jsonify({
            'success': False,
            'error': f'Erro interno: {str(e)}'
        }), 500

@app.route('/list', methods=['GET'])
def list_videos():
    """Lista todos os vídeos disponíveis"""
    try:
        videos = []

        # Listar vídeos processados
        for filename in os.listdir(PROCESSED_FOLDER):
            if filename.endswith(('.mp4', '.mov', '.avi', '.mkv', '.webm')):
                file_path = os.path.join(PROCESSED_FOLDER, filename)
                file_stats = os.stat(file_path)

                videos.append({
                    'filename': filename,
                    'url': f"http://{DOMAIN}/videos/{filename}",
                    'size_mb': round(file_stats.st_size / (1024 * 1024), 2),
                    'created_at': datetime.fromtimestamp(file_stats.st_ctime).isoformat(),
                    'modified_at': datetime.fromtimestamp(file_stats.st_mtime).isoformat()
                })

        # Ordenar por data de modificação (mais recente primeiro)
        videos.sort(key=lambda x: x['modified_at'], reverse=True)

        return jsonify({
            'success': True,
            'count': len(videos),
            'videos': videos
        }), 200

    except Exception as e:
        app.logger.error(f'❌ Erro ao listar vídeos: {str(e)}')
        return jsonify({
            'success': False,
            'error': f'Erro ao listar vídeos: {str(e)}'
        }), 500

@app.route('/delete/<filename>', methods=['DELETE'])
def delete_video(filename):
    """Deleta um vídeo específico"""
    try:
        # Sanitizar nome do arquivo
        filename = secure_filename(filename)
        file_path = os.path.join(PROCESSED_FOLDER, filename)

        # Verificar se arquivo existe
        if not os.path.exists(file_path):
            return jsonify({
                'success': False,
                'error': 'Arquivo não encontrado'
            }), 404

        # Deletar arquivo
        os.remove(file_path)
        app.logger.info(f'🗑️ Arquivo deletado: {filename}')

        return jsonify({
            'success': True,
            'message': f'Vídeo {filename} deletado com sucesso'
        }), 200

    except Exception as e:
        app.logger.error(f'❌ Erro ao deletar vídeo: {str(e)}')
        return jsonify({
            'success': False,
            'error': f'Erro ao deletar vídeo: {str(e)}'
        }), 500

@app.route('/', methods=['GET'])
def index():
    """Página inicial com documentação da API"""
    return jsonify({
        'name': 'Video Hosting API',
        'version': '1.0.0',
        'domain': DOMAIN,
        'endpoints': {
            'POST /upload': 'Upload de vídeo (campo: video)',
            'GET /list': 'Listar todos os vídeos',
            'DELETE /delete/<filename>': 'Deletar vídeo específico',
            'GET /health': 'Status do servidor'
        },
        'limits': {
            'max_file_size': f'{MAX_FILE_SIZE / (1024*1024)}MB',
            'allowed_formats': list(ALLOWED_EXTENSIONS)
        },
        'optimization': {
            'codec': 'H.264',
            'audio': 'AAC',
            'max_resolution': '1080p',
            'platform': 'Instagram'
        }
    }), 200

# ================================================
# INICIALIZAÇÃO
# ================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# ================================================
# 6️⃣ CONFIGURAÇÃO DO NGINX
# ================================================
echo -e "\n${YELLOW}6️⃣ Configurando Nginx...${NC}"
cat > /etc/nginx/sites-available/video-server << 'EOF'
# ================================================
# CONFIGURAÇÃO NGINX - SERVIDOR DE VÍDEOS
# ================================================

server {
    listen 80;
    server_name logiccos.com www.logiccos.com;

    # Logs
    access_log /var/www/videos/logs/nginx-access.log;
    error_log /var/www/videos/logs/nginx-error.log;

    # Limite de upload
    client_max_body_size 500M;
    client_body_timeout 300s;

    # Timeouts para uploads grandes
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    send_timeout 300s;

    # Servir vídeos estáticos com otimização para streaming
    location /videos/ {
        alias /var/www/videos/processed/;

        # Headers para melhor performance
        add_header Cache-Control "public, max-age=31536000";
        add_header X-Content-Type-Options nosniff;

        # Suporte para range requests (streaming)
        add_header Accept-Ranges bytes;

        # CORS
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'Range';

        # Tipos MIME para vídeos
        location ~ \.(mp4|webm|ogg|mov|avi|mkv|m4v)$ {
            mp4;
            mp4_buffer_size 4M;
            mp4_max_buffer_size 10M;
        }

        # Proteção contra hotlinking (opcional - comente se não quiser)
        # valid_referers none blocked server_names *.logiccos.com;
        # if ($invalid_referer) {
        #     return 403;
        # }
    }

    # Proxy para API Flask
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;

        # Preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
}
EOF

# Habilitar site
ln -sf /etc/nginx/sites-available/video-server /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Testar configuração
nginx -t

# ================================================
# 7️⃣ CONFIGURAÇÃO DO SYSTEMD
# ================================================
echo -e "\n${YELLOW}7️⃣ Configurando serviço systemd...${NC}"
cat > /etc/systemd/system/video-api.service << 'EOF'
[Unit]
Description=Video Hosting API for N8N
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt
Environment="PATH=/opt/video_api_env/bin"
ExecStart=/opt/video_api_env/bin/python /opt/video_api.py
Restart=always
RestartSec=10

# Logs
StandardOutput=append:/var/www/videos/logs/api-output.log
StandardError=append:/var/www/videos/logs/api-error.log

[Install]
WantedBy=multi-user.target
EOF

# ================================================
# 8️⃣ SCRIPT DE MONITORAMENTO
# ================================================
echo -e "\n${YELLOW}8️⃣ Criando script de monitoramento...${NC}"
cat > /usr/local/bin/monitor-video-server.sh << 'EOF'
#!/bin/bash

# ================================================
# 📊 SCRIPT DE MONITORAMENTO DO SERVIDOR DE VÍDEOS
# ================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📊 MONITORAMENTO DO SERVIDOR DE VÍDEOS${NC}"
echo -e "${BLUE}📍 Domínio: logiccos.com${NC}"
echo -e "${BLUE}🕐 $(date)${NC}"
echo -e "${BLUE}================================================${NC}\n"

# 1. Status dos serviços
echo -e "${YELLOW}📦 STATUS DOS SERVIÇOS:${NC}"

# Nginx
if systemctl is-active --quiet nginx; then
    echo -e "  ✅ Nginx: ${GREEN}Ativo${NC}"
else
    echo -e "  ❌ Nginx: ${RED}Inativo${NC}"
fi

# API Flask
if systemctl is-active --quiet video-api; then
    echo -e "  ✅ API Flask: ${GREEN}Ativa${NC}"
else
    echo -e "  ❌ API Flask: ${RED}Inativa${NC}"
fi

# 2. Teste de Health Check
echo -e "\n${YELLOW}🏥 HEALTH CHECK:${NC}"
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health)
if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo -e "  ✅ API respondendo: ${GREEN}OK (200)${NC}"
    curl -s http://localhost:5000/health | python3 -m json.tool
else
    echo -e "  ❌ API não respondendo: ${RED}Código $HEALTH_RESPONSE${NC}"
fi

# 3. Uso de disco
echo -e "\n${YELLOW}💾 USO DE DISCO:${NC}"
DISK_USAGE=$(df -h /var/www/videos | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "  ✅ Uso de disco: ${GREEN}${DISK_USAGE}%${NC}"
else
    echo -e "  ⚠️  Uso de disco: ${YELLOW}${DISK_USAGE}%${NC}"
fi

# Tamanho das pastas
echo -e "\n${YELLOW}📁 TAMANHO DAS PASTAS:${NC}"
echo -e "  📂 Upload: $(du -sh /var/www/videos/upload 2>/dev/null | cut -f1)"
echo -e "  📂 Processed: $(du -sh /var/www/videos/processed 2>/dev/null | cut -f1)"
echo -e "  📂 Temp: $(du -sh /var/www/videos/temp 2>/dev/null | cut -f1)"
echo -e "  📂 Logs: $(du -sh /var/www/videos/logs 2>/dev/null | cut -f1)"

# 4. Quantidade de vídeos
echo -e "\n${YELLOW}🎬 ESTATÍSTICAS DE VÍDEOS:${NC}"
VIDEO_COUNT=$(find /var/www/videos/processed -type f -name "*.mp4" 2>/dev/null | wc -l)
echo -e "  📹 Total de vídeos: ${VIDEO_COUNT}"

# 5. Últimos logs de erro
echo -e "\n${YELLOW}📋 ÚLTIMOS ERROS (se houver):${NC}"
if [ -f /var/www/videos/logs/api.log ]; then
    ERRORS=$(grep -i error /var/www/videos/logs/api.log | tail -5)
    if [ -z "$ERRORS" ]; then
        echo -e "  ✅ Nenhum erro recente"
    else
        echo "$ERRORS"
    fi
else
    echo -e "  ℹ️  Arquivo de log não encontrado"
fi

# 6. Processos e memória
echo -e "\n${YELLOW}💻 RECURSOS DO SISTEMA:${NC}"
echo -e "  🔹 CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% em uso"
echo -e "  🔹 RAM: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo -e "  🔹 Processos Python: $(pgrep -c python3)"

echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}📊 FIM DO MONITORAMENTO${NC}"
echo -e "${BLUE}================================================${NC}"
EOF

chmod +x /usr/local/bin/monitor-video-server.sh

# ================================================
# 9️⃣ SCRIPT DE LIMPEZA (OPCIONAL)
# ================================================
echo -e "\n${YELLOW}9️⃣ Criando script de limpeza...${NC}"
cat > /usr/local/bin/cleanup-videos.sh << 'EOF'
#!/bin/bash

# Limpar vídeos temporários mais antigos que 1 dia
find /var/www/videos/temp -type f -mtime +1 -delete

# Limpar logs mais antigos que 30 dias
find /var/www/videos/logs -type f -name "*.log" -mtime +30 -delete

echo "✅ Limpeza concluída em $(date)"
EOF

chmod +x /usr/local/bin/cleanup-videos.sh

# Adicionar ao cron (limpeza diária às 3AM)
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/cleanup-videos.sh >> /var/www/videos/logs/cleanup.log 2>&1") | crontab -

# ================================================
# 🔟 INICIANDO SERVIÇOS
# ================================================
echo -e "\n${YELLOW}🔟 Iniciando serviços...${NC}"

# Recarregar systemd
systemctl daemon-reload

# Iniciar e habilitar API
systemctl start video-api
systemctl enable video-api

# Reiniciar Nginx
systemctl restart nginx
systemctl enable nginx

# ================================================
# 1️⃣1️⃣ CONFIGURAÇÃO DO FIREWALL
# ================================================
echo -e "\n${YELLOW}1️⃣1️⃣ Configurando firewall...${NC}"
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS (para futuro SSL)
ufw allow 5000/tcp # API Flask (apenas local)
ufw --force enable

# ================================================
# ✅ INSTALAÇÃO CONCLUÍDA
# ================================================
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}================================================${NC}"

echo -e "\n${YELLOW}📍 INFORMAÇÕES DO SERVIDOR:${NC}"
echo -e "  🌐 Domínio: ${GREEN}logiccos.com${NC}"
echo -e "  🔗 API URL: ${GREEN}http://logiccos.com${NC}"
echo -e "  📁 Pasta de vídeos: ${GREEN}/var/www/videos${NC}"
echo -e "  📊 Monitoramento: ${GREEN}/usr/local/bin/monitor-video-server.sh${NC}"

echo -e "\n${YELLOW}🔑 ENDPOINTS DISPONÍVEIS:${NC}"
echo -e "  POST   ${GREEN}http://logiccos.com/upload${NC} - Upload de vídeo"
echo -e "  GET    ${GREEN}http://logiccos.com/list${NC} - Listar vídeos"
echo -e "  DELETE ${GREEN}http://logiccos.com/delete/{filename}${NC} - Deletar vídeo"
echo -e "  GET    ${GREEN}http://logiccos.com/health${NC} - Status do servidor"

echo -e "\n${YELLOW}🛠️ COMANDOS ÚTEIS:${NC}"
echo -e "  ${GREEN}systemctl status video-api${NC} - Ver status da API"
echo -e "  ${GREEN}systemctl restart video-api${NC} - Reiniciar API"
echo -e "  ${GREEN}journalctl -u video-api -f${NC} - Ver logs em tempo real"
echo -e "  ${GREEN}monitor-video-server.sh${NC} - Executar monitoramento"

echo -e "\n${YELLOW}📝 TESTE A INSTALAÇÃO:${NC}"
echo -e "  ${GREEN}curl http://logiccos.com/health${NC}"

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}🎉 SERVIDOR PRONTO PARA USO!${NC}"
echo -e "${GREEN}================================================${NC}"