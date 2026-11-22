package com.chenyilong.cyldeallocblockexecutor.binding

import android.app.Activity
import android.app.Application
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.chenyilong.cyldeallocblockexecutor.ConfigSnapshot
import com.chenyilong.cyldeallocblockexecutor.Insets
import com.chenyilong.cyldeallocblockexecutor.LifecycleController
import com.chenyilong.cyldeallocblockexecutor.Size
import java.util.WeakHashMap

/**
 * Feeds the lifecycle controllers from the real Android callbacks: one
 * `Application.ActivityLifecycleCallbacks`, one `FragmentLifecycleCallbacks`
 * per `FragmentActivity` (recursive, so child fragments are covered) and one
 * `ComponentCallbacks2` for configuration and memory.
 *
 * Call [install] once, in `Application.onCreate`. After that every `Activity`
 * and `Fragment` fires its events without code in its overrides; add blocks
 * with `LifecycleRegistry.of(activity)`, or [controllerOf].
 */
object AndroidBinding {
    private val controllers = WeakHashMap<Any, LifecycleController<*>>()
    private val activities = WeakHashMap<Activity, Boolean>()
    private var installed: Application? = null

    /** The controller of an `Activity` or `Fragment`, created on first use. */
    @Synchronized
    fun controllerOf(owner: Any): LifecycleController<Any> {
        @Suppress("UNCHECKED_CAST")
        return controllers.getOrPut(owner) { LifecycleController(owner) } as LifecycleController<Any>
    }

    @Synchronized
    fun install(application: Application) {
        if (installed === application) return
        installed = application
        application.registerActivityLifecycleCallbacks(activityCallbacks)
        application.registerComponentCallbacks(componentCallbacks)
    }

    private fun snapshot(activity: Activity): ConfigSnapshot {
        val c = activity.resources.configuration
        val size = Size(c.screenWidthDp, c.screenHeightDp)
        val night = when (c.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
            Configuration.UI_MODE_NIGHT_YES -> true
            Configuration.UI_MODE_NIGHT_NO -> false
            else -> null
        }
        return ConfigSnapshot(size, night, c.fontScale)
    }

    private fun insetsOf(view: View): Insets? {
        if (Build.VERSION.SDK_INT < 23) return null
        val i = view.rootWindowInsets ?: return null
        return Insets(i.systemWindowInsetTop, i.systemWindowInsetLeft, i.systemWindowInsetBottom, i.systemWindowInsetRight)
    }

    private val activityCallbacks = object : Application.ActivityLifecycleCallbacks {
        private val layoutListeners = WeakHashMap<Activity, ViewTreeObserver.OnGlobalLayoutListener>()

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            synchronized(AndroidBinding) { activities[activity] = true }
            val controller = controllerOf(activity)
            controller.create(snapshot(activity))
            if (activity is FragmentActivity) {
                activity.supportFragmentManager.registerFragmentLifecycleCallbacks(fragmentCallbacks, true)
            }
        }

        override fun onActivityStarted(activity: Activity) {
            val controller = controllerOf(activity)
            controller.start()
            val decor = activity.window.decorView
            val listener = ViewTreeObserver.OnGlobalLayoutListener {
                insetsOf(decor)?.let { controller.insetsChanged(it) }
                controller.layout()
            }
            layoutListeners[activity] = listener
            decor.viewTreeObserver.addOnGlobalLayoutListener(listener)
        }

        override fun onActivityResumed(activity: Activity) {
            val controller = controllerOf(activity)
            controller.resume()
            val decor = activity.window.decorView
            decor.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
                override fun onPreDraw(): Boolean {
                    if (decor.viewTreeObserver.isAlive) decor.viewTreeObserver.removeOnPreDrawListener(this)
                    decor.post { controller.resumedAndDrawn() }
                    return true
                }
            })
        }

        override fun onActivityPaused(activity: Activity) = controllerOf(activity).pause()

        override fun onActivityStopped(activity: Activity) {
            layoutListeners.remove(activity)?.let { l ->
                val vto = activity.window.decorView.viewTreeObserver
                if (vto.isAlive) vto.removeOnGlobalLayoutListener(l)
            }
            controllerOf(activity).stop()
        }

        override fun onActivityDestroyed(activity: Activity) {
            controllerOf(activity).destroy()
            synchronized(AndroidBinding) { activities.remove(activity) }
        }

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    }

    private val fragmentCallbacks = object : FragmentManager.FragmentLifecycleCallbacks() {
        override fun onFragmentAttached(fm: FragmentManager, f: Fragment, context: android.content.Context) =
            controllerOf(f).attach()

        override fun onFragmentViewCreated(fm: FragmentManager, f: Fragment, v: View, savedInstanceState: Bundle?) =
            controllerOf(f).create()

        override fun onFragmentStarted(fm: FragmentManager, f: Fragment) = controllerOf(f).start()

        override fun onFragmentResumed(fm: FragmentManager, f: Fragment) {
            val controller = controllerOf(f)
            controller.resume()
            f.view?.post { controller.resumedAndDrawn() }
        }

        override fun onFragmentPaused(fm: FragmentManager, f: Fragment) = controllerOf(f).pause()
        override fun onFragmentStopped(fm: FragmentManager, f: Fragment) = controllerOf(f).stop()
        override fun onFragmentDestroyed(fm: FragmentManager, f: Fragment) = controllerOf(f).destroy()
    }

    private val componentCallbacks = object : ComponentCallbacks2 {
        override fun onConfigurationChanged(newConfig: Configuration) {
            val live = synchronized(AndroidBinding) { activities.keys.toList() }
            for (a in live) controllerOf(a).configurationChanged(snapshot(a))
        }

        override fun onTrimMemory(level: Int) {
            if (level < ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) return
            fire(level)
        }

        @Deprecated("Deprecated in Java")
        override fun onLowMemory() = fire(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)

        private fun fire(level: Int) {
            val live = synchronized(AndroidBinding) { activities.keys.toList() }
            for (a in live) controllerOf(a).trimMemory(level)
        }
    }
}
