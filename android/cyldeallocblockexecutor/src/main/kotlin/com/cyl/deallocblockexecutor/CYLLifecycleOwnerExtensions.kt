package com.cyl.deallocblockexecutor

import androidx.lifecycle.LifecycleOwner
import java.lang.ref.ReferenceQueue
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

/**
 * A weak key compared by identity, so an owner that overrides equals and hashCode still gets its own registry.
 */
private class CYLIdentityKey(owner: Any, queue: ReferenceQueue<Any>?) : WeakReference<Any>(owner, queue) {
    private val hash = System.identityHashCode(owner)

    override fun hashCode(): Int = hash

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        val mine = get() ?: return false
        return other is CYLIdentityKey && other.get() === mine
    }
}

private val cylRegistries = ConcurrentHashMap<CYLIdentityKey, CYLLifecycleCallbacks<*>>()
private val cylStaleKeys = ReferenceQueue<Any>()

/**
 * The registry of this owner, created on first use and attached to its lifecycle. Owners are matched by identity, never
 * by equals. Call on the main thread.
 */
@Suppress("UNCHECKED_CAST")
fun <T : LifecycleOwner> T.cylLifecycleCallbacks(): CYLLifecycleCallbacks<T> {
    while (true) {
        val stale = cylStaleKeys.poll() ?: break
        cylRegistries.remove(stale)
    }
    val key = CYLIdentityKey(this, cylStaleKeys)
    cylRegistries[key]?.let { return it as CYLLifecycleCallbacks<T> }
    val registry = CYLLifecycleCallbacks(this)
    val existing = cylRegistries.putIfAbsent(key, registry)
    if (existing != null) return existing as CYLLifecycleCallbacks<T>
    registry.attachTo(lifecycle)
    return registry
}
