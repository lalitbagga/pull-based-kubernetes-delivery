const assert = require('node:assert/strict')
const { after, before, test } = require('node:test')
const { createApp } = require('../src/app')

let baseUrl
let server

before(async () => {
  server = createApp({ version: 'test-sha', readinessMode: 'ready' })
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  baseUrl = `http://127.0.0.1:${server.address().port}`
})

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve())
  })
})

test('health reports a live process', async () => {
  const response = await fetch(`${baseUrl}/health`)
  assert.equal(response.status, 200)
  assert.deepEqual(await response.json(), { status: 'healthy' })
})

test('readiness reports a ready application', async () => {
  const response = await fetch(`${baseUrl}/ready`)
  assert.equal(response.status, 200)
  assert.deepEqual(await response.json(), { status: 'ready' })
})

test('version exposes the immutable build identifier', async () => {
  const response = await fetch(`${baseUrl}/version`)
  assert.equal(response.status, 200)
  assert.deepEqual(await response.json(), { version: 'test-sha' })
})

test('readiness can fail without failing liveness', async () => {
  const failingServer = createApp({ readinessMode: 'fail' })
  await new Promise((resolve) => failingServer.listen(0, '127.0.0.1', resolve))
  const failingBaseUrl = `http://127.0.0.1:${failingServer.address().port}`

  const [readiness, health] = await Promise.all([
    fetch(`${failingBaseUrl}/ready`),
    fetch(`${failingBaseUrl}/health`)
  ])

  assert.equal(readiness.status, 503)
  assert.equal(health.status, 200)
  await new Promise((resolve) => failingServer.close(resolve))
})

test('metrics use Prometheus text format', async () => {
  const response = await fetch(`${baseUrl}/metrics`)
  const body = await response.text()

  assert.equal(response.status, 200)
  assert.match(response.headers.get('content-type'), /^text\/plain/)
  assert.match(body, /delivery_api_requests_total [1-9][0-9]*/)
})
