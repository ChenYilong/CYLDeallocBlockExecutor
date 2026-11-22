package com.chenyilong.cyldeallocblockexecutor.binding

import android.app.Activity
import android.app.Application
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import androidx.core.view.ViewCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import com.chenyilong.cyldeallocblockexecutor.ConfigSnapshot
import com.chenyilong.cyldeallocblockexecutor.Insets
import com.chenyilong.cyldeallocblockexecutor.LifecycleController
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.LifecycleRegistry
import com.chenyilong.cyldeallocblockexecutor.Size
import java.util.WeakHashMap

/**
 * Feeds [LifecycleController]s from the real Android callbacks, so any
 * `Activity` or `Fragment` fires the lifecycle events without code in its
 * overrides (the Android counterpart of the iOS `UIViewController` hook).
 *
 * ```kotlin
 * class App : Application() {
 *     override fun onCreate() { super.onCreate(); AndroidBinding.install(this) }
 * }
 * // anywhere, for an Activity or Fragment:
 * AndroidBinding.registry(activity).addLifecycleCallback<Activity>(LifecycleEvent.viewDidAppear) { a, _, _ -> ... }
 * ```
 *
 * Sources: `Application.ActivityLifecycleCallbacks` (create, start, resume,
 * pause, stop, destroy), `FragmentManager.FragmentLifecycleCallbacks`
 * (recursive, for every `FragmentActivity`), `ComponentCallbacks2`
 * (configuration, trim memory), and on the decor view an
 * `OnGlobalLayoutListener` (layout, and the safe-area insets read from the root
 * window insets after each layout). The layout listener and the component
 * callbacks are added when the first block for their events is registered, and
 * removed on destroy. Register blocks for `viewDidLoad` before the owner's
 * `onCreate` returns (for an Activity: before `super.onCreate`, or from an
 * `ActivityLifecycleCallbacks.onActivityPreCreated`).
 */
object AndroidBinding {
    private val activities = WeakHashMap<Activity, ActivityHook>()
    private val fragments = WeakHashMap<Fragment, FragmentHook>()
    private var installedOn: Application? = null

    /** The registry of an `Activity` or `Fragment` (the same object `LifecycleRegistry.of(owner)` returns). */
    @JvmStatic
    fun registry(owner: Any): LifecycleRegistry = LifecycleRegistry.of(owner)

    /** The controller of an owner the binding has seen, or null. */
    @JvmStatic
    fun controller(owner: Any): LifecycleController<*>? =
        synchronized(this) { activities[owner as? Activity]?.controller ?: fragments[owner as? Fragment]?.controller }

    /** Registers the callbacks on [application]; calling it twice is harmless. */
    @JvmStatic
    @Synchronized
    fun install(application: Application) {
        if (installedOn === application) return
        installedOn?.unregisterActivityLifecycleCallbacks(callbacks)
        installedOn = application
        application.registerActivityLifecycleCallbacks(callbacks)
    }

    private fun snapshot(activity: Activity): ConfigSnapshot {
        val c = activity.resources.configuration
        val m = activity.resources.displayMetrics
        return ConfigSnapshot(
            size = Size(m.widthPixels, m.heightPixels),
            nightMode = (c.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES,
            fontScale = c.fontScale,
        )
    }

    private fun insets(view: View): Insets? {
        val i = ViewCompat.getRootWindowInsets(view)?.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars())
            ?: return null
        return Insets(top = i.top, left = i.left, bottom = i.bottom, right = i.right)
    }

    private class ActivityHook(val activity: Activity) {
        val controller = LifecycleController(activity)
        private var layoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
        private var componentCallbacks: ComponentCallbacks2? = null
        private var fragmentCallbacks: FragmentManager.FragmentLifecycleCallbacks? = null

        init {
            controller.registry.onRegister = { event -> attachSources(event) }
        }

        fun created() {
            controller.create(snapshot(activity), null)
            (activity as? FragmentActivity)?.let { fa ->
                val cb = FragmentCallbacks()
                fragmentCallbacks = cb
                fa.supportFragmentManager.registerFragmentLifecycleCallbacks(cb, true)
            }
            // Blocks added before `create` for events that need a source.
            LifecycleEvent.values().forEach { if (controller.registry.hasBlocksFor(it)) attachSources(it) }
        }

        fun attachSources(event: LifecycleEvent) {
            when (event) {
                LifecycleEvent.viewDidLayoutSubviews, LifecycleEvent.viewSafeAreaInsetsDidChange -> {
                    if (layoutListener == null) {
                        val decor = activity.window?.decorView ?: return
                        val l = ViewTreeObserver.OnGlobalLayoutListener {
                            controller.layout()
                            insets(decor)?.let { controller.insetsChanged(it) }
                        }
                        layoutListener = l
                        decor.viewTreeObserver.addOnGlobalLayoutListener(l)
                    }
                }
                LifecycleEvent.viewWillTransition, LifecycleEvent.traitCollectionDidChange, LifecycleEvent.didReceiveMemoryWarning -> {
                    if (componentCallbacks == null) {
                        val cb = object : ComponentCallbacks2 {
                            override fun onConfigurationChanged(newConfig: Configuration) =
                                controller.configurationChanged(snapshot(activity))
                            @Deprecated("Deprecated in Java")
                            override fun onLowMemory() = controller.trimMemory(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
                            override fun onTrimMemory(level: Int) = controller.trimMemory(level)
                        }
                        componentCallbacks = cb
                        activity.registerComponentCallbacks(cb)
                    }
                }
                else -> Unit
            }
        }

        fun resumed() {
            controller.resume()
            // The decor view runs a posted action after the traversal that follows the resume.
            activity.window?.decorView?.post { controller.resumedAndDrawn() } ?: controller.resumedAndDrawn()
        }

        fun destroyed() {
            val decor = activity.window?.decorView
            layoutListener?.let { decor?.viewTreeObserver?.removeOnGlobalLayoutListener(it) }
            layoutListener = null
            componentCallbacks?.let { activity.unregisterComponentCallbacks(it) }
            componentCallbacks = null
            (activity as? FragmentActivity)?.let { fa ->
                fragmentCallbacks?.let { fa.supportFragmentManager.unregisterFragmentLifecycleCallbacks(it) }
            }
            fragmentCallbacks = null
            controller.destroy()
        }
    }

    private class FragmentHook(val fragment: Fragment) {
        val controller = LifecycleController(fragment)
    }

    private fun fragmentHook(f: Fragment): FragmentHook =
        synchronized(this) { fragments.getOrPut(f) { FragmentHook(f) } }

    private class FragmentCallbacks : FragmentManager.FragmentLifecycleCallbacks() {
        override fun onFragmentAttached(fm: FragmentManager, f: Fragment, context: android.content.Context) =
            fragmentHook(f).controller.attach()
        override fun onFragmentViewCreated(fm: FragmentManager, f: Fragment, v: View, savedInstanceState: Bundle?) =
            fragmentHook(f).controller.create()
        override fun onFragmentStarted(fm: FragmentManager, f: Fragment) = fragmentHook(f).controller.start()
        override fun onFragmentResumed(fm: FragmentManager, f: Fragment) {
            val c = fragmentHook(f).controller
            c.resume()
            f.view?.post { c.resumedAndDrawn() } ?: c.resumedAndDrawn()
        }
        override fun onFragmentPaused(fm: FragmentManager, f: Fragment) = fragmentHook(f).controller.pause()
        override fun onFragmentStopped(fm: FragmentManager, f: Fragment) = fragmentHook(f).controller.stop()
        override fun onFragmentDestroyed(fm: FragmentManager, f: Fragment) {
            fragmentHook(f).controller.destroy()
            synchronized(AndroidBinding) { fragments.remove(f) }
        }
    }

    private val callbacks = object : Application.ActivityLifecycleCallbacks {
        private fun hook(a: Activity) = synchronized(AndroidBinding) { activities.getOrPut(a) { ActivityHook(a) } }

        override fun onActivityPreCreated(activity: Activity, savedInstanceState: Bundle?) { hook(activity) }
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = hook(activity).created()
        override fun onActivityStarted(activity: Activity) = hook(activity).controller.start()
        override fun onActivityResumed(activity: Activity) = hook(activity).resumed()
        override fun onActivityPaused(activity: Activity) = hook(activity).controller.pause()
        override fun onActivityStopped(activity: Activity) = hook(activity).controller.stop()
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) {
            hook(activity).destroyed()
            synchronized(AndroidBinding) { activities.remove(activity) }
        }
    }
}
