package com.chenyilong.cyldeallocblockexecutor

/**
 * Debug log of the lifecycle moments (design v5). Off by default: turn it on while developing, read what fires on which owner,
 * in which order, and how many blocks ran. Messages are built lazily, so the disabled path costs one volatile read.
 *
 *     LifecycleLog.enabled = true                          // prints through `sink`
 *     LifecycleLog.sink = { message -> Log.d("CYL", message) }
 */
object LifecycleLog {
    @Volatile var enabled = false
    @Volatile var sink: (String) -> Unit = { println(it) }

    /** A short name for an owner: class name and identity (override it to name your own owners). */
    @Volatile var describer: (Any?) -> String = { owner ->
        if (owner == null) "nil" else "${owner.javaClass.simpleName.ifEmpty { owner.javaClass.name }}@${Integer.toHexString(System.identityHashCode(owner))}"
    }

    fun describe(owner: Any?): String = describer(owner)

    internal inline fun log(message: () -> String) {
        if (enabled) sink("[CYLLifecycle] ${message()}")
    }
}

/** Well-known custom event names posted by the components (the library never posts them itself). */
object AnimationEvents {
    const val didStart = "cyl.animation.didStart"
    const val didPause = "cyl.animation.didPause"
    const val didResume = "cyl.animation.didResume"
    const val didStop = "cyl.animation.didStop"
}

object BadgeEvents {
    const val didShow = "cyl.badge.didShow"
    const val didClear = "cyl.badge.didClear"
    const val didBecomeReady = "cyl.badge.didBecomeReady"
    const val animationDidStart = "cyl.badge.animationDidStart"
    const val animationDidStop = "cyl.badge.animationDidStop"
}
