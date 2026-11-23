package com.chenyilong.cyldeallocblockexecutor

/** The events a block can be added to. Names match the iOS `CYLLifecycleEvent`. */
enum class LifecycleEvent {
    viewDidLoad,
    viewWillAppear,
    viewIsAppearing,
    viewDidAppear,
    viewWillLayoutSubviews,
    viewDidLayoutSubviews,
    viewWillDisappear,
    viewDidDisappear,
    viewSafeAreaInsetsDidChange,
    viewLayoutMarginsDidChange,
    traitCollectionDidChange,
    viewWillTransition,
    willMoveToParent,
    didMoveToParent,
    didReceiveMemoryWarning,

    // Design v5 (observable moments), appended so the existing names stay stable.
    willMoveToWindow,
    didMoveToWindow,
    didEnterScreen,
    didLeaveScreen,
    scrollWillBeginDragging,
    scrollDidEndDragging,
    scrollDidEndScrolling,
}

/**
 * When a block runs relative to the platform's own handling. Android has no
 * `super` to bracket from outside the class, so the controller fires
 * `beforeSuper` then `afterSuper` back to back at the moment the platform
 * reports, and `end` only through `performLifecycle` / `invokeLifecycleCallbacks`.
 */
enum class LifecycleTiming { beforeSuper, afterSuper, end }

data class Insets(val top: Int = 0, val left: Int = 0, val bottom: Int = 0, val right: Int = 0)

data class Size(val width: Int, val height: Int)

/** The values of the configuration the controller compares between two changes. */
data class ConfigSnapshot(val size: Size, val nightMode: Boolean?, val fontScale: Float)

/** What a block can read about the event (iOS `CYLLifecycleInfo`). */
data class LifecycleInfo(
    val event: LifecycleEvent? = null,
    val timing: LifecycleTiming = LifecycleTiming.afterSuper,
    val animated: Boolean = false,
    /** `viewWillTransition`: the new window size. */
    val size: Size? = null,
    /** `traitCollectionDidChange`: the values before the change. */
    val previousNightMode: Boolean? = null,
    val previousFontScale: Float? = null,
    /** `viewSafeAreaInsetsDidChange`: the insets before the change. */
    val previousInsets: Insets? = null,
    /** `willMoveToParent` / `didMoveToParent`: attached to (true) or detached from (false). */
    val parentAttached: Boolean? = null,
    /** `didReceiveMemoryWarning`: the `onTrimMemory` level. */
    val trimLevel: Int? = null,
    /** True for the block of a teardown. */
    val isDealloc: Boolean = false,
    /** Scroll events: the scrolling source (a `RecyclerView`, a `ScrollView`, a view). */
    val scrollView: Any? = null,
    /** `scrollDidEndDragging`: the scroll view keeps moving after the finger lifts. */
    val willDecelerate: Boolean? = null,
    /** `willMoveToWindow` / `didMoveToWindow`: the window token (the attached view), or null when the view leaves the window. */
    val window: Any? = null,
    /** Custom events: the name the event was posted under. */
    val customEvent: String? = null,
    /** Custom events: what the poster passed along. */
    val userInfo: Map<String, Any?>? = null,
)

/** A block: the owner, its own identifier and the info. */
typealias LifecycleCallback<T> = (owner: T, identifier: Int, info: LifecycleInfo) -> Unit
