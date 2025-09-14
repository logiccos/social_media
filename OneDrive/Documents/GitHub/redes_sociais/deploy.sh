#!/bin/bash

# ================================================
# 🚀 DEPLOY AUTOMÁTICO PARA NETLIFY
# ================================================
# Site: silly-paprenjak-99c91c.netlify.app
# ================================================

echo "🚀 Iniciando deploy automático para Netlify..."
echo "📍 Site: silly-paprenjak-99c91c.netlify.app"
echo ""

# Verificar se o Netlify CLI está instalado
if ! command -v netlify &> /dev/null; then
    echo "📦 Instalando Netlify CLI..."
    npm install -g netlify-cli
fi

# Fazer login no Netlify (só precisa fazer uma vez)
echo "🔐 Conectando ao Netlify..."
echo "Se for a primeira vez, uma janela abrirá no navegador para autorizar."
netlify login

# Link do projeto (só precisa fazer uma vez)
echo "🔗 Vinculando ao site silly-paprenjak-99c91c..."
netlify link --id silly-paprenjak-99c91c

# Deploy para produção
echo "🚀 Fazendo deploy..."
netlify deploy --prod --dir=videos-n8n-7x9k2 --functions=netlify/functions

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "📍 URLs do seu projeto:"
echo "  🌐 Site: https://silly-paprenjak-99c91c.netlify.app/videos-n8n-7x9k2/"
echo "  📤 Upload: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/upload"
echo "  📋 Lista: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/list"
echo "  ❤️ Health: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/health"
echo ""
echo "🎯 Use no N8N:"
echo "  URL: https://silly-paprenjak-99c91c.netlify.app/.netlify/functions/upload"