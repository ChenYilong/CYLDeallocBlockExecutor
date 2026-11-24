// Drives the example in WeChat DevTools with miniprogram-automator (NOT yet run: DevTools needs a logged-in account).
// Prerequisites: DevTools logged in (QR scan), Settings > Security > "Service port" on, and a real or test-account appid in
// project.config.json (touristappid is refused: "There is no such AppID").
//   npm i miniprogram-automator   (in a scratch directory)
//   node run-devtools.mjs
import automator from 'miniprogram-automator'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const projectPath = path.dirname(fileURLToPath(import.meta.url))
const cliPath = '/Applications/wechatwebdevtools.app/Contents/MacOS/cli'
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

const mini = await automator.launch({ cliPath, projectPath })
const page = await mini.reLaunch('/pages/index/index')
await sleep(1500)
const log = async () => (await page.data()).log
console.log('after load:', await log())

await mini.pageScrollTo(600)             // onPageScroll -> scrollWillBeginDragging, then end after 150 ms idle
await sleep(600)
console.log('after scroll:', await page.data('count'), 'pauses', await page.data('pauses'), 'resumes', await page.data('resumes'))

await mini.screenshot({ path: 'docs-devtools-scroll.png' })
await mini.navigateTo('/pages/second/second')   // onHide -> viewWillDisappear, viewDidDisappear
await sleep(800)
await mini.navigateBack()                       // onShow -> viewWillAppear ...
await sleep(800)
await mini.callWxMethod('setWindowSize', { width: 500, height: 800 }).catch(() => {})   // onResize -> viewWillTransition
await sleep(500)
console.log('final:', await log())
await mini.close()
