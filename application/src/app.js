const http = require('node:http')

const startedAt = Date.now()
let requestCount = 0

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, { 'content-type': 'application/json; charset=utf-8' })
  response.end(`${JSON.stringify(body)}\n`)
}

function createApp(options = {}) {
  const version = options.version || process.env.APP_VERSION || 'development'
  const readinessMode = options.readinessMode || process.env.READINESS_MODE || 'ready'

  return http.createServer((request, response) => {
    requestCount += 1

    if (request.method !== 'GET') {
      response.setHeader('allow', 'GET')
      return sendJson(response, 405, { error: 'method not allowed' })
    }

    switch (request.url) {
      case '/':
        return sendJson(response, 200, {
          service: 'delivery-api',
          version,
          endpoints: ['/health', '/ready', '/version', '/metrics']
        })
      case '/health':
        return sendJson(response, 200, { status: 'healthy' })
      case '/ready':
        if (readinessMode === 'fail') {
          return sendJson(response, 503, { status: 'not ready' })
        }
        return sendJson(response, 200, { status: 'ready' })
      case '/version':
        return sendJson(response, 200, { version })
      case '/metrics': {
        const uptimeSeconds = Math.floor((Date.now() - startedAt) / 1000)
        response.writeHead(200, { 'content-type': 'text/plain; version=0.0.4; charset=utf-8' })
        return response.end(
          '# HELP delivery_api_requests_total Total HTTP requests received.\n' +
          '# TYPE delivery_api_requests_total counter\n' +
          `delivery_api_requests_total ${requestCount}\n` +
          '# HELP delivery_api_uptime_seconds Process uptime in seconds.\n' +
          '# TYPE delivery_api_uptime_seconds gauge\n' +
          `delivery_api_uptime_seconds ${uptimeSeconds}\n`
        )
      }
      default:
        return sendJson(response, 404, { error: 'not found' })
    }
  })
}

module.exports = { createApp }
