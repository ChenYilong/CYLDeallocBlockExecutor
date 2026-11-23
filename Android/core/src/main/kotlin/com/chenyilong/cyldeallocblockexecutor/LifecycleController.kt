package com.chenyilong.cyldeallocblockexecutor

/**
 * Fires the lifecycle events of an owner (an `Activity`, a `Fragment` or any
 * object) when the platform binding calls its methods: the Android counterpart
 * of the iOS `UIViewController` hook. It holds no Android type, so it runs on
 * the JVM; `AndroidBinding` in the `binding` folder feeds it from the real
 * callbacks.
 *
 * Mapping (iOS event: Android source):
 * - `viewDidLoad`: `create()` (`onCreate`, `onViewCreated`);
 * - `viewWillAppear`: `start()` (`onStart`); `viewIsAppearing`: `resume()`
 *   (`onResume`); `viewDidAppear`: `resumedAndDrawn()` (first frame after
 *   resume); `viewWillDisappear`: `pause()` (`onPause`); `viewDidDisappear`:
 *   `stop()` (`onStop`). App background and foreground go through the same
 *   Android callbacks, so an Activity that returns from the background fires
 *   them again (unlike iOS);
 * - `viewDidLayoutSubviews`: `layout()`; `viewWillLayoutSubviews` has no
 *   source outside a custom `View`;
 * - `viewSafeAreaInsetsDidChange`: `insetsChanged(insets)`;
 *   `viewWillTransition` and `traitCollectionDidChange`:
 *   `configurationChanged(snapshot)` (size / night mode / font scale);
 * - `willMoveToParent` / `didMoveToParent`: `attach()` / `detach()`
 *   (`Fragment.onAttach` / `onDetach`; an Activity attaches in `create()` and
 *   detaches in `destroy()`);
 * - `didReceiveMemoryWarning`: `trimMemory(level)` (`onTrimMemory`,
 *   `onLowMemory`);
 * - `viewLayoutMarginsDidChange`: not available (no layout margins);
 * - design v5: `windowMoved(attached, window)` (`OnAttachStateChangeListener`) fires the window moves;
 *   `screenVisible(visible)` fires `didEnterScreen` / `didLeaveScreen` on transitions (also right after
 *   `viewDidAppear` / `viewDidDisappear`); `scrollBegan`, `scrollEndedDragging(willDecelerate)` and `scrollEnded`
 *   (`RecyclerView.OnScrollListener` states) fire the scroll events.
 *
 * Teardown blocks run in `destroy()`: deterministic for an `Activity` or
 * `Fragment`, not a garbage-collection event.
 */
class LifecycleController<T : Any>(owner: T) {
    val registry: LifecycleRegistry = LifecycleRegistry.of(owner)
    private var attached = false
    private var destroyed = false
    private var appearPending = false
    private var disappearPending = false
    private var lastInsets: Insets? = null
    private var lastConfig: ConfigSnapshot? = null
    private var onScreen = false

    init {
        registry.hookInstalled = true
    }

    private fun around(event: LifecycleEvent, info: LifecycleInfo = LifecycleInfo(), call: () -> Unit = {}) {
        registry.fireAutomatic(event, LifecycleTiming.beforeSuper, info)
        call()
        registry.fireAutomatic(event, LifecycleTiming.afterSuper, info)
    }

    /** The owner was added to its parent. */
    fun attach() {
        if (attached) return
        attached = true
        around(LifecycleEvent.willMoveToParent, LifecycleInfo(parentAttached = true))
        around(LifecycleEvent.didMoveToParent, LifecycleInfo(parentAttached = true))
    }

    /** The owner's view was created. */
    fun create(initialConfig: ConfigSnapshot? = null, initialInsets: Insets? = null) {
        lastConfig = initialConfig ?: lastConfig
        lastInsets = initialInsets ?: lastInsets
        attach()
        around(LifecycleEvent.viewDidLoad)
    }

    fun start() {
        appearPending = true
        around(LifecycleEvent.viewWillAppear)
    }

    fun resume() = around(LifecycleEvent.viewIsAppearing)

    /** The first frame after `resume()` was drawn. */
    fun resumedAndDrawn() {
        if (!appearPending) return
        appearPending = false
        around(LifecycleEvent.viewDidAppear)
        screenVisible(true)
    }

    fun pause() {
        disappearPending = true
        around(LifecycleEvent.viewWillDisappear)
    }

    fun stop() {
        if (!disappearPending) return
        disappearPending = false
        around(LifecycleEvent.viewDidDisappear)
        screenVisible(false)
    }

    fun layout() = around(LifecycleEvent.viewDidLayoutSubviews)

    /** The owner's view joined ([attached] true, with its [window] token) or left the window. */
    fun windowMoved(attached: Boolean, window: Any? = null) {
        val info = LifecycleInfo(window = if (attached) window ?: Any() else null)
        around(LifecycleEvent.willMoveToWindow, info)
        around(LifecycleEvent.didMoveToWindow, info)
        if (!attached) screenVisible(false)
    }

    /** Fires `didEnterScreen` / `didLeaveScreen` on transitions only. */
    fun screenVisible(visible: Boolean) {
        if (onScreen == visible || destroyed) return
        onScreen = visible
        around(if (visible) LifecycleEvent.didEnterScreen else LifecycleEvent.didLeaveScreen)
    }

    /** The user started dragging [source] (`SCROLL_STATE_DRAGGING`). */
    fun scrollBegan(source: Any? = null) = around(LifecycleEvent.scrollWillBeginDragging, LifecycleInfo(scrollView = source))

    /** The finger lifted; [willDecelerate] is true when the source keeps moving (`SCROLL_STATE_SETTLING`). */
    fun scrollEndedDragging(willDecelerate: Boolean, source: Any? = null) {
        around(LifecycleEvent.scrollDidEndDragging, LifecycleInfo(scrollView = source, willDecelerate = willDecelerate))
        if (!willDecelerate) scrollEnded(source)
    }

    /** The source stopped for good (`SCROLL_STATE_IDLE` after settling). */
    fun scrollEnded(source: Any? = null) = around(LifecycleEvent.scrollDidEndScrolling, LifecycleInfo(scrollView = source))

    fun insetsChanged(insets: Insets) {
        val previous = lastInsets
        if (previous == insets) return
        lastInsets = insets
        around(LifecycleEvent.viewSafeAreaInsetsDidChange, LifecycleInfo(previousInsets = previous))
    }

    fun configurationChanged(config: ConfigSnapshot) {
        val previous = lastConfig
        lastConfig = config
        if (previous == null) return
        if (previous.size != config.size) {
            around(LifecycleEvent.viewWillTransition, LifecycleInfo(size = config.size))
        }
        if (previous.nightMode != config.nightMode || previous.fontScale != config.fontScale) {
            around(
                LifecycleEvent.traitCollectionDidChange,
                LifecycleInfo(previousNightMode = previous.nightMode, previousFontScale = previous.fontScale),
            )
        }
    }

    fun trimMemory(level: Int) = around(LifecycleEvent.didReceiveMemoryWarning, LifecycleInfo(trimLevel = level))

    /** The owner is going away: pending did events, the move events, then the teardown blocks. */
    fun destroy() {
        if (destroyed) return
        destroyed = true
        resumedAndDrawn()
        stop()
        around(LifecycleEvent.willMoveToParent, LifecycleInfo(parentAttached = false))
        around(LifecycleEvent.didMoveToParent, LifecycleInfo(parentAttached = false))
        registry.runDealloc()
    }
}
