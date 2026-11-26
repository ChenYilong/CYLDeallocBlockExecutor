// Drives the example in WeChat DevTools with miniprogram-automator and prints one pass / fail line per expected event.
// Prerequisites: DevTools logged in (QR scan), Settings > Security > "Service port" on, `./sync.sh` run, and an appid in
// project.config.json that DevTools accepts for automation.
//   npm i miniprogram-automator          (in a scratch directory; pass it with CYL_AUTOMATOR_DIR=<that directory>)
//   node run-devtools.mjs
// The DevTools CLI is found from WECHAT_DEVTOOLS_CLI, else from the default install path of macOS or Windows.
import { spawn } from 'node:child_process'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs'
import path from 'node:path'

const projectPath = path.dirname(fileURLToPath(import.meta.url))
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

function findCli() {
  if (process.env.WECHAT_DEVTOOLS_CLI) return process.env.WECHAT_DEVTOOLS_CLI
  const candidates = process.platform === 'win32'
    ? [
        path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Tencent', '微信web开发者工具', 'cli.bat'),
        path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Tencent', '微信web开发者工具', 'cli.bat'),
      ]
    : ['/Applications/wechatwebdevtools.app/Contents/MacOS/cli']
  const found = candidates.find((p) => fs.existsSync(p))
  if (!found) throw new Error('WeChat DevTools CLI not found; set WECHAT_DEVTOOLS_CLI. Tried: ' + candidates.join(', '))
  return found
}

function loadAutomator() {
  const base = process.env.CYL_AUTOMATOR_DIR ? path.join(path.resolve(process.env.CYL_AUTOMATOR_DIR), 'package.json') : import.meta.url
  return createRequire(base)('miniprogram-automator')
}

if (!fs.existsSync(path.join(projectPath, 'miniprogram', 'cyl', 'index.js'))) {
  throw new Error('miniprogram/cyl/ is missing: run ./sync.sh first')
}

const automator = loadAutomator()
const cliPath = findCli()
const shotDir = process.env.CYL_SHOT_DIR || projectPath

// automator.launch spawns the CLI without a shell. On Windows the CLI is `cli.bat`, and Node 18.20.2 / 20.12.2 / 22+
// refuse to spawn a .bat file without one (EINVAL, CVE-2024-27980), so start `cli auto` here and connect to its port.
async function launch() {
  if (!cliPath.toLowerCase().endsWith('.bat')) return automator.launch({ cliPath, projectPath })
  const port = Number(process.env.CYL_AUTO_PORT || 9420)
  const quote = (s) => '"' + s + '"'
  // --trust-project: without it a never-trusted project waits on a trust dialog and every automator call times out.
  const cli = spawn(quote(cliPath), ['auto', '--project', quote(projectPath), '--auto-port', String(port), '--trust-project'], { shell: true, stdio: 'inherit' })
  // Poll while the CLI runs (as automator.launch does): it may stay alive on success. A non-zero exit fails at once.
  let exitCode = null
  cli.on('exit', (code) => { exitCode = code === null ? -1 : code })
  const deadline = Date.now() + Number(process.env.CYL_LAUNCH_TIMEOUT_MS || 60000)
  while (Date.now() < deadline) {
    if (exitCode !== null && exitCode !== 0) throw new Error('`cli auto` exited with code ' + exitCode + ' (see its output above)')
    try {
      const connected = await automator.connect({ wsEndpoint: 'ws://127.0.0.1:' + port })
      console.log('stage: connected to automation port ' + port)
      // Until the first page is registered, reLaunch throws "Cannot destructure property 'rawPath' of
      // 't.getPageMetaByWebviewId(...)' as it is null". automator.launch sleeps 5 s; a cold project needs longer, so poll.
      for (let wait = 0; wait < 60; wait++) {
        const current = await connected.currentPage().catch(() => null)
        if (current && current.path) { console.log('stage: first page ready: ' + current.path); break }
        await sleep(1000)
      }
      await sleep(1000)
      return connected
    } catch (e) { await sleep(1000) }
  }
  throw new Error('could not connect to DevTools automation on port ' + port)
}

// touristappid is refused ("There is no such AppID"). CYL_APPID swaps in an appid for this run only and restores the file.
const configPath = path.join(projectPath, 'project.config.json')
const originalConfig = fs.readFileSync(configPath, 'utf8')
const restoreConfig = () => fs.writeFileSync(configPath, originalConfig)
// The automator can throw from its own timers (uncaught), which skips `finally`; restore on exit too.
process.on('exit', restoreConfig)
if (process.env.CYL_APPID) {
  fs.writeFileSync(configPath, JSON.stringify(Object.assign(JSON.parse(originalConfig), { appid: process.env.CYL_APPID }), null, 2) + '\n')
}

// Every `CYL EVENT n <name>` console line from the page, in order.
const events = []
const sizes = []   // the `size=WxH` of each viewWillTransition
let mini
try {
  mini = await launch()
} catch (e) {
  restoreConfig()
  throw e
}
mini.on('console', (msg) => {
  const text = (msg.args || []).join(' ')
  const m = /^CYL EVENT \d+ (\S+)(?: size=(\S+))?/.exec(text)
  if (m) events.push(m[1])
  if (m && m[2]) sizes.push(m[2])
})
const mark = () => events.length
const since = (i) => events.slice(i)

// Page.callMethod answered "this.<name> is not a function" (DevTools 2.02, Windows) although the current page has
// the method (checked through getCurrentPages()), so call it inside the app service instead.
async function callOnCurrentPage(name, arg) {
  const outcome = await mini.evaluate((method, value) => {
    const pages = getCurrentPages()
    const p = pages[pages.length - 1]
    if (typeof p[method] !== 'function') return 'missing ' + method + ' on ' + p.route
    p[method](value)
    return 'called ' + method + ' on ' + p.route
  }, name, arg).catch((e) => 'evaluate failed: ' + e.message)
  console.log(outcome)
}

const results = []
const check = (name, ok, detail) => {
  results.push({ name, ok })
  console.log((ok ? 'PASS ' : 'FAIL ') + name + (detail ? '  ' + detail : ''))
}

try {
  console.log('stage: reLaunch index')
  let page = await mini.reLaunch('/pages/index/index')
  await sleep(1500)
  const load = since(0)
  console.log('load events:', load.join(', '))
  check('onLoad -> viewDidLoad', load.includes('viewDidLoad'))
  check('onShow -> viewWillAppear', load.includes('viewWillAppear'))
  check('onReady -> viewDidAppear', load.includes('viewDidAppear'))

  // Scroll: onPageScroll starts the drag; the end must come about 150 ms after the last scroll.
  let i = mark()
  const before = { pauses: await page.data('pauses'), resumes: await page.data('resumes') }
  await mini.pageScrollTo(600)
  await sleep(60)
  const midPauses = await page.data('pauses')
  const midResumes = await page.data('resumes')
  await sleep(600)
  const after = { pauses: await page.data('pauses'), resumes: await page.data('resumes') }
  console.log('scroll events:', since(i).join(', '), '| pauses', before.pauses, '->', midPauses, '->', after.pauses,
    '| resumes', before.resumes, '->', midResumes, '->', after.resumes)
  check('scroll begin (pause)', after.pauses === before.pauses + 1)
  check('scroll end after idle (resume)', after.resumes === before.resumes + 1 && midResumes === before.resumes,
    'resume not yet fired 60 ms after the scroll: ' + (midResumes === before.resumes))
  await mini.screenshot({ path: path.join(shotDir, 'miniprogram-devtools-windows-scroll.png') }).catch((e) => console.log('screenshot failed:', e.message))

  // Push and Back: onHide, then onShow.
  i = mark()
  await mini.navigateTo('/pages/second/second')
  await sleep(800)
  const hide = since(i)
  console.log('push events:', hide.join(', '))
  check('onHide -> viewWillDisappear / viewDidDisappear', hide.includes('viewWillDisappear') && hide.includes('viewDidDisappear'))
  i = mark()
  await mini.navigateBack()
  await sleep(800)
  // navigateBack can resolve with the page being closed; read the current page after the stack settles.
  page = await mini.currentPage()
  console.log('current page after Back:', page.path)
  const back = since(i)
  console.log('back events:', back.join(', '))
  check('onShow after Back -> viewWillAppear / viewDidAppear', back.includes('viewWillAppear') && back.includes('viewDidAppear'))

  // Theme: DevTools has no automator switch for the simulator theme; the page forwards wx.onThemeChange by hand,
  // so drive the controller with the same call the system callback makes.
  // themeChanged ignores an unchanged theme, so send the opposite of the one the page recorded at onLoad.
  const info = await mini.callWxMethod('getAppBaseInfo').catch(() => ({}))
  const nextTheme = info && info.theme === 'dark' ? 'light' : 'dark'
  i = mark()
  await callOnCurrentPage('cylTheme', nextTheme)
  await sleep(300)
  const theme = since(i)
  console.log('theme events:', theme.join(', '))
  check('theme change -> traitCollectionDidChange', theme.includes('traitCollectionDidChange'), '(forwarded call, not the system switch)')

  // Resize: automation has no simulator rotate or resize, so call the page's onResize with the payload the system
  // passes on rotation ("pageOrientation": "auto" in index.json lets a manual rotation in DevTools fire it too).
  i = mark()
  await callOnCurrentPage('onResize', { deviceOrientation: 'landscape', size: { windowWidth: 812, windowHeight: 375 } })
  await sleep(500)
  const resize = since(i)
  console.log('resize events:', resize.join(', '))
  check('onResize -> viewWillTransition', resize.includes('viewWillTransition'), '(forwarded call, not a real rotation)')
  check('viewWillTransition carries the nested system size', sizes[sizes.length - 1] === '812x375', 'size=' + sizes[sizes.length - 1])

  // Unload: reLaunch closes every page, so the index page gets onUnload.
  i = mark()
  await mini.reLaunch('/pages/second/second')
  await sleep(800)
  const unload = since(i)
  console.log('unload events:', unload.join(', '))
  check('onUnload -> teardown', unload.includes('teardown'))
} finally {
  const failed = results.filter((r) => !r.ok).length
  console.log('RESULT: ' + (results.length - failed) + ' / ' + results.length + ' passed')
  process.exitCode = failed || results.length === 0 ? 1 : 0
  console.log('all events:', events.join(', '))
  await mini.close().catch(() => {})
  restoreConfig()
}
