package com.chenyilong.cyldeallocblockexecutor

import java.lang.ref.WeakReference
import kotlin.reflect.KClass

/**
 * Global observers: one block that observes an event on every object, for behavior that must not know its owners ("pause every
 * animation while the user scrolls"). Per-owner blocks run first, then the global ones, each group in identifier order. Global
 * observers never receive teardown events: the owner is going away. A key replaces the observer added before under it.
 */
object LifecycleCenter {
    private class GlobalEntry(
        val identifier: Int,
        val callback: LifecycleCallback<Any>,
        val event: LifecycleEvent?,
        val custom: String?,
        val timing: LifecycleTiming,
        val ownerType: KClass<*>?,
        val key: String?,
    )

    private val lock = Any()
    private var entries = mutableListOf<GlobalEntry>()
    private var nextIdentifier = 1
    private val scrolling = mutableListOf<WeakReference<Any>>()

    /** True while any observed scroll source is dragging or decelerating. */
    val isUserScrolling: Boolean
        get() = synchronized(lock) {
            scrolling.removeAll { it.get() == null }
            scrolling.isNotEmpty()
        }

    @Suppress("UNCHECKED_CAST")
    fun <T : Any> addCallback(
        event: LifecycleEvent,
        timing: LifecycleTiming = LifecycleTiming.afterSuper,
        ownerType: KClass<*>? = null,
        key: String? = null,
        callback: LifecycleCallback<T>,
    ): Int = add(GlobalEntry(0, callback as LifecycleCallback<Any>, event, null, timing, ownerType, key))

    @Suppress("UNCHECKED_CAST")
    fun <T : Any> addCustomCallback(
        name: String,
        ownerType: KClass<*>? = null,
        key: String? = null,
        callback: LifecycleCallback<T>,
    ): Int = add(GlobalEntry(0, callback as LifecycleCallback<Any>, null, name, LifecycleTiming.afterSuper, ownerType, key))

    private fun add(prototype: GlobalEntry): Int = synchronized(lock) {
        if (prototype.key != null) entries.removeAll { it.key == prototype.key }
        val id = nextIdentifier++
        entries.add(GlobalEntry(id, prototype.callback, prototype.event, prototype.custom, prototype.timing, prototype.ownerType, prototype.key))
        id
    }

    /** Cancels one observer by [identifier] or by [key]; true when one was removed. */
    fun cancelCallback(identifier: Int? = null, key: String? = null): Boolean {
        require((identifier == null) != (key == null)) { "pass exactly one of identifier or key" }
        return synchronized(lock) { entries.removeAll { if (identifier != null) it.identifier == identifier else it.key == key } }
    }

    /** For tests: removes every observer and forgets the scroll state. */
    fun reset() {
        synchronized(lock) {
            entries = mutableListOf()
            scrolling.clear()
        }
    }

    /** Called by a registry after the owner's own blocks of (event, timing) ran. */
    internal fun dispatch(owner: Any, event: LifecycleEvent?, custom: String?, timing: LifecycleTiming, info: LifecycleInfo) {
        if (event == LifecycleEvent.scrollWillBeginDragging) synchronized(lock) { scrolling.add(WeakReference(owner)) }
        if (event == LifecycleEvent.scrollDidEndScrolling) synchronized(lock) { scrolling.removeAll { it.get() == null || it.get() === owner } }
        val snapshot = synchronized(lock) {
            if (entries.isEmpty()) return
            entries.filter { it.event == event && it.custom == custom && (custom != null || it.timing == timing) }.sortedBy { it.identifier }
        }
        for (e in snapshot) {
            if (!synchronized(lock) { entries.contains(e) }) continue
            if (e.ownerType != null && !e.ownerType.isInstance(owner)) continue
            e.callback(owner, e.identifier, info.copy(event = event, timing = timing, customEvent = custom))
        }
    }
}
