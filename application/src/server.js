const { createApp } = require('./app')

const port = Number.parseInt(process.env.PORT || '8080', 10)
const server = createApp()

server.listen(port, '0.0.0.0', () => {
  console.log(`delivery-api listening on port ${port}`)
})

function shutDown(signal) {
  console.log(`${signal} received; stopping delivery-api`)
  server.close((error) => {
    if (error) {
      console.error(error)
      process.exitCode = 1
    }
  })
}

process.on('SIGTERM', () => shutDown('SIGTERM'))
process.on('SIGINT', () => shutDown('SIGINT'))
