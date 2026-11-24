// Device check page: one block per event on the page's registry, logged to the console (tag CYL) and on screen.
const { withLifecycle, LifecycleRegistry, LifecycleCenter, LifecycleEvent } = require('../../cyl/index.js')

const rows = []
for (let i = 0; i < 60; i++) rows.push(i)

function register(page) {
  // Blocks are added before the controller reports onLoad, so the first events are not missed.
  const registry = LifecycleRegistry.of(page)
  page.cylCounts = { n: 0, pauses: 0, resumes: 0 }
  Object.keys(LifecycleEvent).forEach((name) => {
    registry.addLifecycleCallback(name, () => {
      page.cylCounts.n += 1
      const line = 'EVENT ' + page.cylCounts.n + ' ' + name
      console.log('CYL ' + line)
      const log = (page.data.log || []).concat(line).slice(-12)
      page.setData({ log, count: page.cylCounts.n })
    })
  })
  LifecycleCenter.whileUserScrolls(
    () => { page.cylCounts.pauses += 1; page.setData({ pauses: page.cylCounts.pauses }) },
    () => { page.cylCounts.resumes += 1; page.setData({ resumes: page.cylCounts.resumes }) },
    { key: 'example.scroll' }
  )
}

const options = withLifecycle({
  data: { log: [], rows, count: 0, pauses: 0, resumes: 0 },
  onLoad() {
    // Not wrapped: the library does not own these two system callbacks, forward them by hand.
    wx.onThemeChange && wx.onThemeChange((res) => this.cylController && this.cylController.themeChanged(res.theme))
    wx.onMemoryWarning && wx.onMemoryWarning(() => this.cylController && this.cylController.memoryWarning())
    const info = wx.getAppBaseInfo ? wx.getAppBaseInfo() : {}
    this.cylController.themeChanged(info.theme || 'light')
  },
  goSecond() { wx.navigateTo({ url: '/pages/second/second' }) },
})

const wrappedOnLoad = options.onLoad
options.onLoad = function (...args) {
  register(this)
  return wrappedOnLoad.apply(this, args)
}
Page(options)
