package com.chenyilong.cyldeallocblockexecutor

import java.lang.ref.WeakReference

private class Entry(
    val identifier: Int,
    val callback: LifecycleCallback<Any>,
    val event: LifecycleEvent?, // null: a teardown block
    val timing: LifecycleTiming,
    val invokeOnce: Boolean,
    val key: String?,
) {
    var fired = false
    var cancelled = false
}

/**
 * One registry per owner: the lifecycle blocks and the teardown blocks.
 *
 * The iOS rules (see `docs/Lifecycle-Callbacks.md`): one identifier counter for
 * every block; blocks run in identifier order from a snapshot, taken under the
 * lock and run after it is released, so a block can add or cancel blocks;
 * adding with a key replaces the block added before under that key (the new
 * block starts unfired; keys are separate for lifecycle and teardown blocks);
 * keyed blocks belong to their key holder: cancel-all and re-arm by event skip
 * them.
 */
class LifecycleRegistry(owner: Any) {
    companion object {
        // Owners are keyed by identity, not equals / hashCode: two equal data-class owners must not share a registry.
        private val registries = HashMap<Int, MutableList<LifecycleRegistry>>()

        /** The registry of [owner], created on first use. */
        @JvmStatic
        fun of(owner: Any): LifecycleRegistry = synchronized(registries) {
            registries.values.forEach { list -> list.removeAll { it.owner.get() == null } }
            registries.values.removeAll { it.isEmpty() }
            val bucket = registries.getOrPut(System.identityHashCode(owner)) { mutableListOf() }
            bucket.firstOrNull { it.owner.get() === owner } ?: LifecycleRegistry(owner).also { bucket.add(it) }
        }
    }

    private val owner: WeakReference<Any> = WeakReference(owner)
    private val lock = Any()
    private var entries = mutableListOf<Entry>()
    private var nextIdentifier = 1
    private val manual = mutableSetOf<Pair<LifecycleEvent, LifecycleTiming>>()
    private val performDepth = mutableMapOf<LifecycleEvent, Int>()

    /** Called after a block is added for an event (the binding registers its listeners lazily). */
    @Volatile
    var onRegister: ((LifecycleEvent) -> Unit)? = null

    /** The controller sets this once its automatic hooks fire `beforeSuper` / `afterSuper`. */
    @Volatile
    var hookInstalled = false

    val blockCount: Int get() = synchronized(lock) { entries.count { !it.cancelled } }

    fun hasBlocksFor(event: LifecycleEvent): Boolean =
        synchronized(lock) { entries.any { it.event == event && !it.cancelled } }

    private fun drop(match: (Entry) -> Boolean) {
        entries.filter(match).forEach { it.cancelled = true }
        entries.removeAll { it.cancelled }
    }

    // lifecycle blocks

    /** Adds a block for [event]; returns its identifier. */
    @Suppress("UNCHECKED_CAST")
    fun <T : Any> addLifecycleCallback(
        event: LifecycleEvent,
        timing: LifecycleTiming = LifecycleTiming.afterSuper,
        invokeOnce: Boolean = false,
        key: String? = null,
        callback: LifecycleCallback<T>,
    ): Int {
        val id = synchronized(lock) {
            if (key != null) drop { it.key == key && it.event != null }
            val id = nextIdentifier++
            entries.add(Entry(id, callback as LifecycleCallback<Any>, event, timing, invokeOnce, key))
            id
        }
        onRegister?.invoke(event)
        return id
    }

    /** Cancels one block by [identifier] or by [key]; true when one was removed. */
    fun cancelLifecycleCallback(identifier: Int? = null, key: String? = null): Boolean =
        cancelOne(identifier, key, dealloc = false)

    /** Cancels the blocks of [event] (and [timing] when given) that have no key. */
    fun cancelAllLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming? = null) {
        synchronized(lock) {
            drop { it.event == event && it.key == null && (timing == null || it.timing == timing) }
        }
    }

    /** Lets the invoke-once blocks of [event] without a key run once more. */
    fun rearmLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming? = null) {
        synchronized(lock) {
            entries.filter { it.event == event && it.key == null && (timing == null || it.timing == timing) }
                .forEach { it.fired = false }
        }
    }

    /** Re-arms the one block added under [key]. */
    fun rearmLifecycleCallback(key: String) {
        synchronized(lock) { entries.filter { it.event != null && it.key == key }.forEach { it.fired = false } }
    }

    // teardown blocks

    /** Adds a teardown block: it runs once, when the owner is torn down. */
    @Suppress("UNCHECKED_CAST")
    fun <T : Any> addDeallocCallback(key: String? = null, callback: LifecycleCallback<T>): Int =
        synchronized(lock) {
            if (key != null) drop { it.key == key && it.event == null }
            val id = nextIdentifier++
            entries.add(Entry(id, callback as LifecycleCallback<Any>, null, LifecycleTiming.end, false, key))
            id
        }

    fun cancelDeallocCallback(identifier: Int? = null, key: String? = null): Boolean =
        cancelOne(identifier, key, dealloc = true)

    /** Cancels the teardown blocks that have no key. */
    fun cancelAllDeallocCallbacks() {
        synchronized(lock) { drop { it.event == null && it.key == null } }
    }

    private fun cancelOne(identifier: Int?, key: String?, dealloc: Boolean): Boolean {
        require((identifier == null) != (key == null)) { "pass exactly one of identifier or key" }
        synchronized(lock) {
            val hit = entries.firstOrNull {
                (it.event == null) == dealloc && (if (identifier != null) it.identifier == identifier else it.key == key)
            } ?: return false
            hit.cancelled = true
            entries.remove(hit)
            return true
        }
    }

    /** Runs the teardown blocks in identifier order, once. The owner calls this when it is torn down. */
    fun runDealloc() {
        val target = owner.get() ?: return
        val snapshot = synchronized(lock) {
            val s = entries.filter { it.event == null }.sortedBy { it.identifier }
            entries.removeAll { it.event == null }
            s
        }
        for (e in snapshot) {
            if (e.cancelled) continue
            e.callback(target, e.identifier, LifecycleInfo(timing = LifecycleTiming.end, isDealloc = true))
        }
    }

    // dispatch

    /** Declares that the owner dispatches [events] itself, for [timings] (all by default). */
    fun setManualLifecycleDispatch(
        manual: Boolean,
        events: Set<LifecycleEvent>,
        timings: Set<LifecycleTiming> = LifecycleTiming.values().toSet(),
    ) {
        synchronized(lock) {
            for (e in events) for (t in timings) if (manual) this.manual.add(e to t) else this.manual.remove(e to t)
        }
    }

    fun isManual(event: LifecycleEvent, timing: LifecycleTiming): Boolean =
        synchronized(lock) { (event to timing) in manual }

    /** True when the controller's automatic hook fires this (event, timing). */
    fun isAutomatic(event: LifecycleEvent, timing: LifecycleTiming): Boolean =
        hookInstalled && timing != LifecycleTiming.end && !isManual(event, timing)

    /** Fires the blocks of one (event, timing) for the automatic hooks; skips a timing declared manual. */
    fun fireAutomatic(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo = LifecycleInfo()) {
        if (isManual(event, timing)) return
        fire(event, timing, info)
    }

    /** Fires the blocks of one (event, timing) by hand. The event must be declared manual first. */
    fun invokeLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo = LifecycleInfo()) {
        check(isManual(event, timing)) { "declare $event / $timing manual with setManualLifecycleDispatch first" }
        fire(event, timing, info)
    }

    /**
     * Runs [callSuper], then [body], with the timings around them. With the
     * controller's hook the automatic timings come from the hook; this adds
     * `end` after [body], at the outermost level only and not when `end` is
     * declared manual. For an owner without a hook all three timings fire from
     * the outermost call.
     */
    fun performLifecycle(
        event: LifecycleEvent,
        info: LifecycleInfo = LifecycleInfo(),
        callSuper: () -> Unit,
        body: () -> Unit,
    ) {
        val depth = synchronized(lock) { (performDepth[event] ?: 0).also { performDepth[event] = it + 1 } }
        val outermost = depth == 0
        try {
            if (!hookInstalled && outermost) fireAutomatic(event, LifecycleTiming.beforeSuper, info)
            callSuper()
            if (!hookInstalled && outermost) fireAutomatic(event, LifecycleTiming.afterSuper, info)
            body()
            if (outermost) fireAutomatic(event, LifecycleTiming.end, info)
        } finally {
            synchronized(lock) { performDepth[event] = depth }
        }
    }

    private fun fire(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo) {
        val target = owner.get() ?: return
        val snapshot = synchronized(lock) {
            entries.filter { it.event == event && it.timing == timing && !(it.invokeOnce && it.fired) }
                .sortedBy { it.identifier }
        }
        for (e in snapshot) {
            val run = synchronized(lock) {
                if (e.cancelled || (e.invokeOnce && e.fired)) false else { if (e.invokeOnce) e.fired = true; true }
            }
            if (run) e.callback(target, e.identifier, info.copy(event = event, timing = timing))
        }
    }
}
