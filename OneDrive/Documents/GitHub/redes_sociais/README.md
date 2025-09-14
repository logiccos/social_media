# 🎬 Social Media Video API

Sistema de hospedagem de vídeos otimizado para N8N e Instagram, hospedado no Netlify.

## 🚀 Deploy Rápido

[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/logiccos/social_media)

## 📍 URLs de Produção

🌐 **Site em Produção**: https://silly-paprenjak-99c91c.netlify.app

- **Interface**: https://silly-paprenjak-99c91c.netlify.app/videos-n8n-7x9k2/
- **API Upload**: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/upload
- **API List**: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/list
- **API Health**: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/health

## 🛠️ Configuração Local

```bash
# Clonar repositório
git clone https://github.com/logiccos/social_media.git
cd social_media

# Instalar Netlify CLI
npm install -g netlify-cli

# Rodar localmente
netlify dev
```

## 📱 Configuração no N8N

### HTTP Request Node - Upload de Vídeo

```json
{
  "method": "POST",
  "url": "https://[seu-site].netlify.app/.netlify/functions/upload",
  "authentication": "None",
  "sendBody": true,
  "bodyContentType": "multipart-form-data",
  "bodyParameters": {
    "parameters": [{
      "parameterType": "formBinaryData",
      "name": "video",
      "inputDataFieldName": "data"
    }]
  }
}
```

## 📂 Estrutura do Projeto

```
/
├── netlify.toml              # Configuração do Netlify
├── package.json              # Dependências do projeto
├── videos-n8n-7x9k2/        # Pasta pública com interface
│   └── index.html           # Interface de teste da API
└── netlify/
    └── functions/           # Serverless functions
        ├── upload.js        # Endpoint de upload
        ├── list.js          # Endpoint de listagem
        └── health.js        # Health check
```

## 🎯 Funcionalidades

- ✅ Upload de vídeos via API REST
- ✅ Otimização automática para Instagram
- ✅ CORS habilitado para N8N
- ✅ Limite de 500MB por arquivo
- ✅ Interface web para testes
- ✅ Serverless (sem necessidade de VPS)

## 🔧 Variáveis de Ambiente (Opcional)

No painel do Netlify, adicione:

```env
MAX_FILE_SIZE=524288000
ALLOWED_FORMATS=mp4,mov,avi,mkv,webm
```

## 📊 Limites

- **Tamanho máximo**: 500MB por vídeo
- **Formatos**: MP4, MOV, AVI, MKV, WebM
- **Otimização**: H.264 + AAC (Instagram)
- **Resolução máxima**: 1080p

## 🚀 Deploy em 1 Clique

1. Clique no botão "Deploy to Netlify" acima
2. Conecte sua conta GitHub
3. Confirme o deploy
4. Pronto! Sua API está online

## 📝 Teste Manual

```bash
# Health check
curl https://[seu-site].netlify.app/.netlify/functions/health

# Upload de vídeo
curl -X POST \
  -F "video=@video.mp4" \
  https://[seu-site].netlify.app/.netlify/functions/upload
```

## 🤝 Suporte

Para dúvidas ou problemas, abra uma issue no GitHub.

---

**Desenvolvido para integração com N8N e Instagram** 🚀