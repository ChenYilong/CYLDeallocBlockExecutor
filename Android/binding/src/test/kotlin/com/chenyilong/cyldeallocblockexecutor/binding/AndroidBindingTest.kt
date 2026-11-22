package com.chenyilong.cyldeallocblockexecutor.binding

import android.app.Application
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.LifecycleRegistry
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals

class HostActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(FrameLayout(this).apply { id = 1001 })
    }
}

class PlainFragment : Fragment() {
    override fun onCreateView(i: android.view.LayoutInflater, c: android.view.ViewGroup?, s: android.os.Bundle?): View = View(requireContext())
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AndroidBindingTest {
    private lateinit var app: Application
    private val log = mutableListOf<String>()

    @Before fun setUp() {
        app = ApplicationProvider.getApplicationContext()
        AndroidBinding.install(app)
        log.clear()
    }

    private fun <T : Any> LifecycleRegistry.watch(owner: T, vararg events: LifecycleEvent) {
        for (e in events) addLifecycleCallback<T>(e) { _, _, _ -> log.add(e.name) }
    }

    @Test fun activityCallbacksFireTheIosEventsInOrder() {
        ActivityScenario.launch(HostActivity::class.java).use { s ->
            s.onActivity { a ->
                // already created and started when we get it: add blocks for the later events
                LifecycleRegistry.of(a).watch(a, LifecycleEvent.viewWillDisappear, LifecycleEvent.viewDidDisappear, LifecycleEvent.willMoveToParent)
            }
            s.moveToState(Lifecycle.State.CREATED)
            assertEquals(listOf("viewWillDisappear", "viewDidDisappear"), log)
        }
        assertEquals(listOf("viewWillDisappear", "viewDidDisappear", "willMoveToParent"), log)
    }

    @Test fun createdStartedResumedFireInOrderOnALaunch() {
        val owners = mutableListOf<HostActivity>()
        app.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityPreCreated(a: android.app.Activity, b: android.os.Bundle?) {
                if (a is HostActivity) {
                    owners.add(a)
                    LifecycleRegistry.of(a).watch(a, LifecycleEvent.viewDidLoad, LifecycleEvent.viewWillAppear, LifecycleEvent.viewIsAppearing, LifecycleEvent.viewDidAppear)
                }
            }
            override fun onActivityCreated(a: android.app.Activity, b: android.os.Bundle?) {}
            override fun onActivityStarted(a: android.app.Activity) {}
            override fun onActivityResumed(a: android.app.Activity) {}
            override fun onActivityPaused(a: android.app.Activity) {}
            override fun onActivityStopped(a: android.app.Activity) {}
            override fun onActivitySaveInstanceState(a: android.app.Activity, b: android.os.Bundle) {}
            override fun onActivityDestroyed(a: android.app.Activity) {}
        })
        ActivityScenario.launch(HostActivity::class.java).use {
            shadowOf(android.os.Looper.getMainLooper()).idle()
            // viewDidAppear comes after the first frame of the resumed activity
            assertEquals(listOf("viewDidLoad", "viewWillAppear", "viewIsAppearing", "viewDidAppear"), log)
        }
    }

    @Test fun destroyRunsMoveEventsThenTeardownBlocks() {
        ActivityScenario.launch(HostActivity::class.java).use { s ->
            s.onActivity { a ->
                val r = LifecycleRegistry.of(a)
                r.watch(a, LifecycleEvent.didMoveToParent)
                r.addDeallocCallback<HostActivity> { o, _, info -> log.add("dealloc ${info.isDealloc} ${o === a}") }
            }
        }
        assertEquals(listOf("didMoveToParent", "dealloc true true"), log)
    }

    @Test fun configurationAndMemoryReachTheLiveActivity() {
        ActivityScenario.launch(HostActivity::class.java).use { s ->
            s.onActivity { a ->
                LifecycleRegistry.of(a).watch(a, LifecycleEvent.didReceiveMemoryWarning)
            }
            app.onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE)
            assertEquals(emptyList(), log)
            app.onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
            assertEquals(listOf("didReceiveMemoryWarning"), log)
        }
    }

    @Test fun fragmentCallbacksFireForAFragment() {
        ActivityScenario.launch(HostActivity::class.java).use { s ->
            s.onActivity { a ->
                val f = PlainFragment()
                LifecycleRegistry.of(f).watch(f, LifecycleEvent.willMoveToParent, LifecycleEvent.viewDidLoad,
                    LifecycleEvent.viewWillAppear, LifecycleEvent.viewIsAppearing, LifecycleEvent.viewWillDisappear)
                LifecycleRegistry.of(f).addDeallocCallback<PlainFragment> { _, _, _ -> log.add("dealloc") }
                a.supportFragmentManager.beginTransaction().add(1001, f).commitNow()
                assertEquals(listOf("willMoveToParent", "viewDidLoad", "viewWillAppear", "viewIsAppearing"), log)
                a.supportFragmentManager.beginTransaction().remove(f).commitNow()
            }
        }
        assertEquals(listOf("willMoveToParent", "viewDidLoad", "viewWillAppear", "viewIsAppearing", "viewWillDisappear", "willMoveToParent", "dealloc"), log)
    }

    @Test fun globalLayoutFiresViewDidLayoutSubviewsAndNightModeFiresTraitChange() {
        ActivityScenario.launch(HostActivity::class.java).use { s ->
            s.onActivity { a ->
                LifecycleRegistry.of(a).watch(a, LifecycleEvent.viewDidLayoutSubviews, LifecycleEvent.traitCollectionDidChange)
                a.window.decorView.viewTreeObserver.dispatchOnGlobalLayout()
            }
            assertEquals(listOf("viewDidLayoutSubviews"), log)
            log.clear()
            s.onActivity { a ->
                val c = Configuration(a.resources.configuration)
                c.uiMode = (c.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or Configuration.UI_MODE_NIGHT_YES
                a.resources.updateConfiguration(c, a.resources.displayMetrics)
                app.onConfigurationChanged(c)
            }
            assertEquals(listOf("traitCollectionDidChange"), log)
        }
    }
}
