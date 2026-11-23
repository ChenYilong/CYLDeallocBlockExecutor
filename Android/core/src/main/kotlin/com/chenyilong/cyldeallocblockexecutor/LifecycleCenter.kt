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

    /**
     * The ready-made version of "pause every animation while the user scrolls, resume afterwards": [pause] runs when any observed
     * scroll source starts to be dragged, [resume] when it stopped for good. Returns a function that removes both observers; they
     * use the keys `<key>.pause` and `<key>.resume` (default key `cyl.scroll`), so calling it again replaces the earlier pair.
     */
    fun whileUserScrolls(key: String = "cyl.scroll", pause: () -> Unit, resume: () -> Unit): () -> Unit {
        addCallback<Any>(LifecycleEvent.scrollWillBeginDragging, key = "$key.pause") { _, _, _ -> pause() }
        addCallback<Any>(LifecycleEvent.scrollDidEndScrolling, key = "$key.resume") { _, _, _ -> resume() }
        return {
            cancelCallback(key = "$key.pause")
            cancelCallback(key = "$key.resume")
        }
    }

    /** Cancels one observer by [identifier] or by [key]; true when one was removed. */
    fun cancelCallback(identifier: Int? = null, key: String? = null): Boolean {
        require((identifier == null) != (key == null)) { "pass exactly one of identifier or key" }
        return synchronized(lock) { entries.removeAll { if (identifier != null) it.identifier == identifier else it.key == key } }
    }

    private class DeallocObserver(val identifier: Int, val key: String?, val callback: (String, LifecycleInfo) -> Unit)

    private var deallocObservers = mutableListOf<DeallocObserver>()

    /**
     * Observes the teardown of every owner that has a registry, to know when any object goes away. The callback gets a description
     * (class name and identity), never the owner: it is being destroyed. For logging and bookkeeping, not for cleanup.
     */
    fun addDeallocObserver(key: String? = null, callback: (description: String, info: LifecycleInfo) -> Unit): Int = synchronized(lock) {
        if (key != null) deallocObservers.removeAll { it.key == key }
        val id = nextIdentifier++
        deallocObservers.add(DeallocObserver(id, key, callback))
        id
    }

    fun cancelDeallocObserver(identifier: Int? = null, key: String? = null): Boolean {
        require((identifier == null) != (key == null)) { "pass exactly one of identifier or key" }
        return synchronized(lock) { deallocObservers.removeAll { if (identifier != null) it.identifier == identifier else it.key == key } }
    }

    /** Called by a registry when its owner's teardown blocks ran. */
    internal fun dispatchDealloc(description: String) {
        LifecycleLog.log { "dealloc $description" }
        val info = LifecycleInfo(timing = LifecycleTiming.end, isDealloc = true)
        for (o in synchronized(lock) { deallocObservers.toList() }) o.callback(description, info)
    }

    /** For tests: removes every observer and forgets the scroll state. */
    fun reset() {
        synchronized(lock) {
            deallocObservers = mutableListOf()
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
