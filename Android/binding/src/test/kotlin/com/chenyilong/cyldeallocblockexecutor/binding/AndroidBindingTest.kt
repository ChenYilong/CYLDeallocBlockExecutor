package com.chenyilong.cyldeallocblockexecutor.binding

import android.app.Activity
import android.app.Application
import android.content.ComponentCallbacks2
import android.os.Looper
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.test.core.app.ApplicationProvider
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent.*
import com.chenyilong.cyldeallocblockexecutor.LifecycleTiming
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

// Robolectric drives the real Activity and Fragment callbacks on the JVM (no device or emulator).
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AndroidBindingTest {
    private lateinit var app: Application
    private val log = mutableListOf<String>()

    @Before
    fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        AndroidBinding.install(app)
        log.clear()
    }

    private fun watch(owner: Any, vararg events: LifecycleEvent) {
        for (ev in events) for (t in listOf(LifecycleTiming.beforeSuper, LifecycleTiming.afterSuper)) {
            AndroidBinding.registry(owner).addLifecycleCallback<Any>(ev, t) { _, _, _ -> log += "$ev/$t" }
        }
    }

    private fun after() = log.filter { it.endsWith("afterSuper") }.map { it.substringBefore('/') }
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    @Test
    fun activityFiresLoadAppearAndDisappearEventsInOrder() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        watch(activity, viewDidLoad, willMoveToParent, didMoveToParent, viewWillAppear, viewIsAppearing,
            viewDidAppear, viewWillDisappear, viewDidDisappear)
        c.create().start()
        assertEquals(listOf("willMoveToParent", "didMoveToParent", "viewDidLoad", "viewWillAppear"), after())
        c.resume()
        assertTrue("viewDidAppear waits for the traversal after resume", "viewDidAppear" !in after())
        idle()
        assertEquals(listOf("viewIsAppearing", "viewDidAppear"), after().drop(4))
        log.clear()
        c.pause()
        assertEquals(listOf("viewWillDisappear"), after())
        c.stop()
        assertEquals(listOf("viewWillDisappear", "viewDidDisappear"), after())
    }

    @Test
    fun destroyRunsTeardownBlocksAfterTheMoveEventsAndRemovesTheSources() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        watch(activity, willMoveToParent)
        AndroidBinding.registry(activity).addDeallocCallback<Activity> { a, _, i ->
            assertTrue(i.isDealloc); assertTrue(a === activity); log += "dealloc"
        }
        c.create().start().resume()
        idle()
        log.clear()
        c.pause().stop().destroy()
        assertEquals("dealloc", log.last())
        assertTrue(log.contains("willMoveToParent/afterSuper"))
        assertTrue(AndroidBinding.controller(activity) == null)
    }

    @Test
    fun globalLayoutFiresViewDidLayoutSubviewsWithInvokeOnce() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        var count = 0
        var onceCount = 0
        AndroidBinding.registry(activity).addLifecycleCallback<Activity>(viewDidLayoutSubviews) { _, _, _ -> count++ }
        AndroidBinding.registry(activity).addLifecycleCallback<Activity>(viewDidLayoutSubviews, invokeOnce = true) { _, _, _ -> onceCount++ }
        c.create()
        activity.setContentView(FrameLayout(activity))
        c.start().postCreate(null).resume().visible()
        idle()
        assertTrue("a layout pass fired the block (count=$count)", count >= 1)
        assertEquals(1, onceCount)
        activity.window.decorView.requestLayout()
        activity.window.decorView.viewTreeObserver.dispatchOnGlobalLayout()
        assertEquals(1, onceCount)
    }

    @Test
    fun configurationChangeFeedsTraitAndTransition() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        val traits = mutableListOf<Boolean?>()
        AndroidBinding.registry(activity).addLifecycleCallback<Activity>(traitCollectionDidChange) { _, _, i -> traits += i.previousNightMode }
        c.create().start().resume()
        org.robolectric.RuntimeEnvironment.setQualifiers("+night")
        activity.resources.updateConfiguration(app.resources.configuration, activity.resources.displayMetrics)
        app.onConfigurationChanged(app.resources.configuration)
        assertEquals(listOf<Boolean?>(false), traits)
    }

    @Test
    fun trimMemoryFiresDidReceiveMemoryWarningWithTheLevel() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        val levels = mutableListOf<Int?>()
        AndroidBinding.registry(activity).addLifecycleCallback<Activity>(didReceiveMemoryWarning) { _, _, i -> levels += i.trimLevel }
        c.create().start().resume()
        app.onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
        assertEquals(listOf<Int?>(ComponentCallbacks2.TRIM_MEMORY_COMPLETE), levels)
        c.pause().stop().destroy()
        app.onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
        assertEquals("the callback was removed on destroy", 1, levels.size)
    }

    class TestFragment : Fragment()

    @Test
    fun fragmentFiresEventsAndTearsDownWhenRemoved() {
        val c = Robolectric.buildActivity(FragmentActivity::class.java)
        val activity = c.get()
        c.create()
        val fragment = TestFragment()
        watch(fragment, willMoveToParent, viewDidLoad, viewWillAppear, viewIsAppearing, viewDidAppear,
            viewWillDisappear, viewDidDisappear)
        AndroidBinding.registry(fragment).addDeallocCallback<Fragment> { f, _, _ -> assertTrue(f === fragment); log += "dealloc" }
        activity.setContentView(FrameLayout(activity).apply { id = 1001 })
        activity.supportFragmentManager.beginTransaction().add(1001, fragment).commitNow()
        c.start().postCreate(null).resume().visible()
        idle()
        assertEquals(
            listOf("willMoveToParent", "viewDidLoad", "viewWillAppear", "viewIsAppearing", "viewDidAppear"),
            after().distinct().let { a -> listOf("willMoveToParent", "viewDidLoad", "viewWillAppear", "viewIsAppearing", "viewDidAppear").filter { it in a } },
        )
        log.clear()
        activity.supportFragmentManager.beginTransaction().remove(fragment).commitNow()
        assertTrue(after().containsAll(listOf("viewWillDisappear", "viewDidDisappear")))
        assertEquals("dealloc", log.last())
        assertTrue(AndroidBinding.controller(fragment) == null)
    }
}
