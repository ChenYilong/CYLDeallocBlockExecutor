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
  const cli = spawn(quote(cliPath), ['auto', '--project', quote(projectPath), '--auto-port', String(port)], { shell: true, stdio: 'inherit' })
  const exited = new Promise((resolve) => cli.on('exit', resolve))
  await exited
  for (let tries = 0; tries < 30; tries++) {
    try { return await automator.connect({ wsEndpoint: 'ws://127.0.0.1:' + port }) } catch (e) { await sleep(1000) }
  }
  throw new Error('could not connect to DevTools automation on port ' + port)
}

// touristappid is refused ("There is no such AppID"). CYL_APPID swaps in an appid for this run only and restores the file.
const configPath = path.join(projectPath, 'project.config.json')
const originalConfig = fs.readFileSync(configPath, 'utf8')
const restoreConfig = () => fs.writeFileSync(configPath, originalConfig)
if (process.env.CYL_APPID) {
  fs.writeFileSync(configPath, JSON.stringify(Object.assign(JSON.parse(originalConfig), { appid: process.env.CYL_APPID }), null, 2) + '\n')
}

// Every `CYL EVENT n <name>` console line from the page, in order.
const events = []
let mini
try {
  mini = await launch()
} catch (e) {
  restoreConfig()
  throw e
}
mini.on('console', (msg) => {
  const text = (msg.args || []).join(' ')
  const m = /^CYL EVENT \d+ (\S+)/.exec(text)
  if (m) events.push(m[1])
})
const mark = () => events.length
const since = (i) => events.slice(i)

const results = []
const check = (name, ok, detail) => {
  results.push({ name, ok })
  console.log((ok ? 'PASS ' : 'FAIL ') + name + (detail ? '  ' + detail : ''))
}

try {
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
  page = await mini.navigateBack()
  await sleep(800)
  const back = since(i)
  console.log('back events:', back.join(', '))
  check('onShow after Back -> viewWillAppear / viewDidAppear', back.includes('viewWillAppear') && back.includes('viewDidAppear'))

  // Theme: DevTools has no automator switch for the simulator theme; the page forwards wx.onThemeChange by hand,
  // so drive the controller with the same call the system callback makes.
  i = mark()
  await page.callMethod('cylTheme', 'dark').catch((e) => console.log('theme call failed:', e.message))
  await sleep(300)
  const theme = since(i)
  console.log('theme events:', theme.join(', '))
  check('theme change -> traitCollectionDidChange', theme.includes('traitCollectionDidChange'), '(forwarded call, not the system switch)')

  // Resize: onResize needs "pageOrientation": "auto" or a resizable window.
  i = mark()
  await mini.callWxMethod('setWindowSize', { width: 500, height: 800 }).catch((e) => console.log('setWindowSize:', e.message))
  await sleep(500)
  const resize = since(i)
  console.log('resize events:', resize.join(', '))
  check('onResize -> viewWillTransition', resize.includes('viewWillTransition'))

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
  console.log('all events:', events.join(', '))
  await mini.close().catch(() => {})
  restoreConfig()
}
