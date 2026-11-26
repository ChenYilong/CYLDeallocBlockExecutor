// A local HTTP proxy for WeChat DevTools on a high-latency link (verified from New Zealand, 2026-11-27).
//
// Why: DevTools' backend is Node, whose "happy eyeballs" (autoSelectFamily) gives each address about 250 ms. From far
// away, servicewechat.com and open.weixin.qq.com then fail with `AggregateError [ETIMEDOUT]` (`internalConnectMultiple`),
// so login checks pass but AppID permissions, `get_user_appids` and `cli auto` fail. The packaged DevTools ignores
// NODE_OPTIONS and its CLI has no proxy option. This proxy connects upstream with one address and a normal timeout.
//
// Use:
//   node no-happy-eyeballs-proxy.mjs [port]          (default 18080; listens on 127.0.0.1 only, logs every target)
//   DevTools: Settings > Proxy > manual, 127.0.0.1:<port> (stored as proxy.proxyType "PROXY 127.0.0.1:<port>"),
//   restart DevTools, run run-devtools.mjs, then set the proxy back to "system".
import net from 'node:net'
import http from 'node:http'

net.setDefaultAutoSelectFamily(false)
const port = Number(process.argv[2] || 18080)
const log = (s) => console.log(new Date().toISOString().slice(11, 23), s)

// Plain http requests with an absolute URI.
const server = http.createServer((req, res) => {
  let url
  try { url = new URL(req.url) } catch (e) { res.writeHead(400).end(); return }
  log('HTTP ' + url.host)
  const options = { host: url.hostname, port: url.port || 80, method: req.method, path: url.pathname + url.search, headers: req.headers }
  const up = http.request(options, (r) => {
    res.writeHead(r.statusCode, r.headers)
    r.pipe(res)
  })
  up.on('error', (e) => { log('HTTP ERR ' + url.host + ' ' + e.code); res.destroy() })
  req.pipe(up)
})

// https through CONNECT tunnels.
server.on('connect', (req, client, head) => {
  const [host, p] = req.url.split(':')
  const t0 = Date.now()
  const up = net.connect({ host, port: Number(p || 443) }, () => {
    log('CONNECT ' + req.url + ' ok ' + (Date.now() - t0) + 'ms')
    client.write('HTTP/1.1 200 Connection Established\r\n\r\n')
    if (head && head.length) up.write(head)
    up.pipe(client)
    client.pipe(up)
  })
  up.setTimeout(20000, () => up.destroy(new Error('ETIMEDOUT')))
  up.on('error', (e) => { log('CONNECT ERR ' + req.url + ' ' + (e.code || e.message)); client.destroy() })
  client.on('error', () => up.destroy())
})

server.listen(port, '127.0.0.1', () => log('listening on 127.0.0.1:' + port))
