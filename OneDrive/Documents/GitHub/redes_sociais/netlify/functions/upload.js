// Netlify Function - Upload de Vídeos
const crypto = require('crypto');

exports.handler = async (event, context) => {
  // CORS Headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS'
  };

  // Handle preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  // Só aceita POST
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers,
      body: JSON.stringify({
        success: false,
        error: 'Method not allowed'
      })
    };
  }

  try {
    // Parse do body (base64 encoded)
    const contentType = event.headers['content-type'] || '';

    if (!event.body) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          success: false,
          error: 'No video data received'
        })
      };
    }

    // Decodificar base64
    const videoBuffer = Buffer.from(event.body, 'base64');

    // Verificar tamanho (max 500MB)
    const maxSize = 500 * 1024 * 1024;
    if (videoBuffer.length > maxSize) {
      return {
        statusCode: 413,
        headers,
        body: JSON.stringify({
          success: false,
          error: `File too large. Max: ${maxSize / (1024*1024)}MB`
        })
      };
    }

    // Gerar nome único
    const timestamp = Date.now();
    const hash = crypto.createHash('md5')
      .update(`video_${timestamp}`)
      .digest('hex')
      .substring(0, 8);
    const filename = `video_${timestamp}_${hash}.mp4`;

    // Como o Netlify não tem storage persistente,
    // vamos retornar uma URL simulada ou integrar com serviço externo
    // Opções: Cloudinary, AWS S3, ou Firebase Storage

    // Por enquanto, vamos simular o sucesso
    const videoUrl = `https://logiccos.netlify.app/videos/${filename}`;

    return {
      statusCode: 200,
      headers: {
        ...headers,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        success: true,
        message: 'Video uploaded successfully',
        data: {
          filename: filename,
          url: videoUrl,
          size_mb: (videoBuffer.length / (1024 * 1024)).toFixed(2),
          timestamp: new Date().toISOString()
        }
      })
    };

  } catch (error) {
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
};