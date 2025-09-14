// Listar Vídeos
exports.handler = async (event, context) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS'
  };

  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  // Simulação de lista de vídeos
  // Em produção, isso viria de um banco de dados ou storage
  const videos = [
    {
      filename: 'video_example_1.mp4',
      url: 'https://logiccos.netlify.app/videos/video_example_1.mp4',
      size_mb: 25.4,
      created_at: new Date().toISOString()
    }
  ];

  return {
    statusCode: 200,
    headers: {
      ...headers,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      success: true,
      count: videos.length,
      videos: videos
    })
  };
};