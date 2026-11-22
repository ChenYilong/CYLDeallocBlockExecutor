package com.chenyilong.cyldeallocblockexecutor

import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent.*
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

// Controller tests drive the controller the way the Android binding does:
// JVM only, no device or emulator run.
class LifecycleControllerTest {
    private lateinit var owner: Any
    private lateinit var c: LifecycleController<Any>
    private val log = mutableListOf<String>()

    @BeforeTest
    fun setUp() {
        owner = Any()
        c = LifecycleController(owner)
        log.clear()
    }

    private fun watch(vararg events: LifecycleEvent) {
        for (ev in events) for (t in listOf(LifecycleTiming.beforeSuper, LifecycleTiming.afterSuper)) {
            c.registry.addLifecycleCallback<Any>(ev, t) { _, _, _ -> log += "$ev/$t" }
        }
    }

    private fun after() = log.filter { it.endsWith("afterSuper") }.map { it.substringBefore('/') }

    @Test fun createFiresMoveAndLoadEventsWithTimings() {
        val attached = mutableListOf<Boolean?>()
        watch(willMoveToParent, viewDidLoad, didMoveToParent)
        c.registry.addLifecycleCallback<Any>(willMoveToParent) { _, _, i -> attached += i.parentAttached }
        c.create()
        assertEquals(
            listOf("willMoveToParent/beforeSuper", "willMoveToParent/afterSuper", "didMoveToParent/beforeSuper",
                "didMoveToParent/afterSuper", "viewDidLoad/beforeSuper", "viewDidLoad/afterSuper"), log)
        c.destroy()
        assertEquals(listOf<Boolean?>(true, false), attached)
    }

    @Test fun appearAndDisappearWillDidSplit() {
        watch(viewWillAppear, viewIsAppearing, viewDidAppear, viewWillDisappear, viewDidDisappear)
        c.start()
        assertEquals(listOf("viewWillAppear"), after())
        c.resume()
        c.resumedAndDrawn()
        assertEquals(listOf("viewWillAppear", "viewIsAppearing", "viewDidAppear"), after())
        log.clear()
        c.pause()
        assertEquals(listOf("viewWillDisappear"), after())
        c.stop()
        assertEquals(listOf("viewWillDisappear", "viewDidDisappear"), after())
    }

    @Test fun backgroundAndForegroundFireAppearEventsAgainAndroidDiffersFromIos() {
        watch(viewWillAppear)
        c.start(); c.stop(); c.start()
        assertEquals(listOf("viewWillAppear", "viewWillAppear"), after())
    }

    @Test fun pendingDidEventsFlushOnDestroy() {
        watch(viewDidAppear, viewDidDisappear)
        c.start(); c.pause()
        c.destroy()
        assertEquals(listOf("viewDidAppear", "viewDidDisappear"), after())
    }

    @Test fun layoutFiresDidLayoutWithInvokeOnceAndRearm() {
        c.registry.addLifecycleCallback<Any>(viewDidLayoutSubviews, invokeOnce = true) { _, _, _ -> log += "layout" }
        c.layout(); c.layout()
        assertEquals(listOf("layout"), log)
        c.registry.rearmLifecycleCallbacks(viewDidLayoutSubviews)
        c.layout()
        assertEquals(listOf("layout", "layout"), log)
    }

    @Test fun insetsWithThePreviousInsetsUnchangedDoNotFire() {
        val seen = mutableListOf<Insets?>()
        c.create(initialInsets = Insets())
        c.registry.addLifecycleCallback<Any>(viewSafeAreaInsetsDidChange) { _, _, i -> seen += i.previousInsets }
        c.insetsChanged(Insets())
        assertEquals(emptyList(), seen)
        c.insetsChanged(Insets(top = 47, bottom = 34))
        assertEquals(listOf<Insets?>(Insets()), seen)
    }

    @Test fun configurationSizeFeedsViewWillTransitionNightModeAndFontScaleFeedTrait() {
        val sizes = mutableListOf<Size?>()
        val prev = mutableListOf<Pair<Boolean?, Float?>>()
        c.create(initialConfig = ConfigSnapshot(Size(400, 800), false, 1f))
        c.registry.addLifecycleCallback<Any>(viewWillTransition) { _, _, i -> sizes += i.size }
        c.registry.addLifecycleCallback<Any>(traitCollectionDidChange) { _, _, i -> prev += i.previousNightMode to i.previousFontScale }
        c.configurationChanged(ConfigSnapshot(Size(800, 400), false, 1f))
        assertEquals(listOf<Size?>(Size(800, 400)), sizes)
        assertEquals(emptyList(), prev)
        c.configurationChanged(ConfigSnapshot(Size(800, 400), true, 1.3f))
        assertEquals(listOf<Pair<Boolean?, Float?>>(false to 1f), prev)
        assertEquals(1, sizes.size)
    }

    @Test fun trimMemoryFiresDidReceiveMemoryWarningWithTheLevel() {
        val levels = mutableListOf<Int?>()
        c.registry.addLifecycleCallback<Any>(didReceiveMemoryWarning) { _, _, i -> levels += i.trimLevel }
        c.trimMemory(80)
        assertEquals(listOf<Int?>(80), levels)
    }

    @Test fun destroyRunsTeardownBlocksInOrderOnceAndTwiceIsHarmless() {
        c.registry.addDeallocCallback<Any> { _, _, _ -> log += "a" }
        c.registry.addDeallocCallback<Any> { _, _, _ -> log += "b" }
        c.destroy(); c.destroy()
        assertEquals(listOf("a", "b"), log)
    }

    @Test fun manualEndBesideAutomaticAfterSuper() {
        c.registry.setManualLifecycleDispatch(true, setOf(viewDidLayoutSubviews), setOf(LifecycleTiming.end))
        c.registry.addLifecycleCallback<Any>(viewDidLayoutSubviews, LifecycleTiming.end, invokeOnce = true, key = "cyl.core.layoutBlock") { _, _, _ -> log += "end-block" }
        c.registry.addLifecycleCallback<Any>(viewDidLayoutSubviews) { _, _, _ -> log += "after" }
        c.layout()
        assertEquals(listOf("after"), log)
        c.registry.invokeLifecycleCallbacks(viewDidLayoutSubviews, LifecycleTiming.end)
        assertEquals(listOf("after", "end-block"), log)
        assertTrue(c.registry.blockCount == 2)
    }
}
