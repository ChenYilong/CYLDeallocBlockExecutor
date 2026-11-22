package com.cyl.deallocblockexecutor

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import java.lang.ref.WeakReference
import java.util.TreeMap

/**
 * A callback with the owner's own type, the identifier of the callback and the info of the event.
 */
typealias CYLLifecycleCallback<T> = (owner: T, id: Long, info: CYLLifecycleInfo) -> Unit

/**
 * The callbacks of one owner: lifecycle callbacks (addCallback) and dealloc callbacks (willDealloc), as the iOS
 * CYLCallbackModel holds them. The owner is held weakly. Identifiers ascend from 1 and are shared by both kinds; 0 is
 * illegal. Callbacks run in identifier order, outside the lock, so a callback can add or cancel callbacks. Nothing here
 * hooks the garbage collector: dealloc runs on DESTROY (attachTo) or when the owner calls dealloc.
 *
 * @param owner the object the callbacks belong to; not retained.
 */
class CYLLifecycleCallbacks<T : Any>(owner: T) {

    private class Entry<T : Any>(
        val id: Long,
        val event: CYLLifecycleEvent?,
        val isDealloc: Boolean,
        val invokeOnce: Boolean,
        val key: String?,
        val callback: CYLLifecycleCallback<T>,
        var fired: Boolean = false,
    )

    private val ownerReference = WeakReference(owner)
    private val lock = Any()
    private val entries = TreeMap<Long, Entry<T>>()
    private val keys = HashMap<String, Long>()
    private var lastId = 0L
    private var deallocated = false

    /**
     * Adds a callback run at event. Several callbacks per event run in the order they were added.
     *
     * @param event the event to wait for.
     * @param invokeOnce run once until rearm (or a replacement under the same key).
     * @param key replaces the callback added before under the same key; the replacement starts armed.
     * @param callback the owner, the identifier of this callback and the info.
     * @return the identifier, or cylDeallocCallbackIllegalIdentifier after dealloc.
     */
    fun addCallback(
        event: CYLLifecycleEvent,
        invokeOnce: Boolean = false,
        key: String? = null,
        callback: CYLLifecycleCallback<T>,
    ): Long = add(event, false, invokeOnce, key, callback)

    /**
     * Adds a callback run once when the owner is deallocated (DESTROY, or dealloc), in identifier order.
     *
     * @param key replaces the callback added before under the same key.
     * @param callback the owner, the identifier of this callback and the info (isDealloc is true).
     * @return the identifier, or cylDeallocCallbackIllegalIdentifier after dealloc.
     */
    fun willDealloc(key: String? = null, callback: CYLLifecycleCallback<T>): Long = add(null, true, false, key, callback)

    private fun add(
        event: CYLLifecycleEvent?,
        isDealloc: Boolean,
        invokeOnce: Boolean,
        key: String?,
        callback: CYLLifecycleCallback<T>,
    ): Long = synchronized(lock) {
        if (deallocated) return cylDeallocCallbackIllegalIdentifier
        val id = ++lastId
        if (key != null) {
            keys[key]?.let { entries.remove(it) }
            keys[key] = id
        }
        entries[id] = Entry(id, event, isDealloc, invokeOnce, key, callback)
        id
    }

    /**
     * Cancels one callback.
     *
     * @return true once, false when no callback has this identifier (never added, cancelled, or 0).
     */
    fun cancel(id: Long): Boolean = synchronized(lock) {
        val entry = entries.remove(id) ?: return false
        entry.key?.let { if (keys[it] == id) keys.remove(it) }
        true
    }

    /**
     * Cancels the callback added under key.
     *
     * @return true once, false when no callback has this key.
     */
    fun cancel(key: String): Boolean = synchronized(lock) {
        val id = keys[key] ?: return false
        cancel(id)
    }

    /**
     * Cancels the lifecycle callbacks of event added without a key. Keyed callbacks belong to whoever holds the key.
     *
     * @param event the event.
     */
    fun cancelAll(event: CYLLifecycleEvent) = synchronized(lock) {
        entries.values.removeAll { it.key == null && !it.isDealloc && it.event == event }
    }

    /**
     * Cancels the willDealloc callbacks added without a key. Keyed callbacks belong to whoever holds the key.
     */
    fun cancelAllWillDealloc() = synchronized(lock) {
        entries.values.removeAll { it.key == null && it.isDealloc }
    }

    /**
     * Lets the invokeOnce callback added under key run once more.
     *
     * @return true when a callback has this key.
     */
    fun rearm(key: String): Boolean = synchronized(lock) {
        val entry = keys[key]?.let { entries[it] } ?: return false
        entry.fired = false
        true
    }

    /**
     * Lets the invokeOnce callbacks of event added without a key run once more; keyed callbacks are re-armed by key.
     *
     * @param event the event.
     */
    fun rearm(event: CYLLifecycleEvent) = synchronized(lock) {
        entries.values.filter { it.key == null && !it.isDealloc && it.event == event }.forEach { it.fired = false }
    }

    /**
     * Runs the callbacks waiting for event now, in identifier order, outside the lock. A callback cancelled by an earlier
     * one of the same run does not run. Does nothing when the owner is gone.
     *
     * @param event the event.
     * @param info the arguments; the event is filled in.
     */
    fun perform(event: CYLLifecycleEvent, info: CYLLifecycleInfo = CYLLifecycleInfo()) {
        val owner = ownerReference.get() ?: return
        val run = synchronized(lock) {
            entries.values.filter { !it.isDealloc && it.event == event && !(it.invokeOnce && it.fired) }
                .onEach { if (it.invokeOnce) it.fired = true }
        }
        val runInfo = info.copy(event = event, isDealloc = false)
        for (entry in run) {
            if (synchronized(lock) { entries[entry.id] === entry }) entry.callback(owner, entry.id, runInfo)
        }
    }

    /**
     * Attaches to a Lifecycle: its events are dispatched with perform, and ON_DESTROY runs dealloc. Call on the main thread.
     *
     * @param lifecycle the lifecycle of the owner.
     */
    fun attachTo(lifecycle: Lifecycle) {
        lifecycle.addObserver(
            LifecycleEventObserver { _, androidEvent ->
                val event = when (androidEvent) {
                    Lifecycle.Event.ON_CREATE -> CYLLifecycleEvent.CREATE
                    Lifecycle.Event.ON_START -> CYLLifecycleEvent.START
                    Lifecycle.Event.ON_RESUME -> CYLLifecycleEvent.RESUME
                    Lifecycle.Event.ON_PAUSE -> CYLLifecycleEvent.PAUSE
                    Lifecycle.Event.ON_STOP -> CYLLifecycleEvent.STOP
                    Lifecycle.Event.ON_DESTROY -> CYLLifecycleEvent.DESTROY
                    else -> return@LifecycleEventObserver
                }
                perform(event)
                if (event == CYLLifecycleEvent.DESTROY) dealloc(event)
            },
        )
    }

    /**
     * Runs the willDealloc callbacks once, in identifier order, then clears everything. A second call does nothing; cancel
     * calls made by the callbacks have no effect.
     */
    fun dealloc() = dealloc(null)

    private fun dealloc(event: CYLLifecycleEvent?) {
        val run = synchronized(lock) {
            if (deallocated) return
            deallocated = true
            val taken = entries.values.filter { it.isDealloc }
            entries.clear()
            keys.clear()
            taken
        }
        val owner = ownerReference.get() ?: return
        val info = CYLLifecycleInfo(event = event, isDealloc = true)
        for (entry in run) entry.callback(owner, entry.id, info)
    }
}
