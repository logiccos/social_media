// Health Check Endpoint
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

  return {
    statusCode: 200,
    headers: {
      ...headers,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      status: 'healthy',
      service: 'Video API - Netlify',
      timestamp: new Date().toISOString(),
      endpoints: {
        upload: '/.netlify/functions/upload',
        health: '/.netlify/functions/health',
        list: '/.netlify/functions/list'
      }
    })
  };
};