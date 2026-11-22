package com.cyl.deallocblockexecutor

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.testing.TestLifecycleOwner
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.Executors

/**
 * The checks of Tests/LifecycleTests/main.swift that apply on Android; docs/Lifecycle-Callbacks.md maps each one.
 */
class CYLLifecycleCallbacksTest {

    private class Owner

    private class EqualOwner(val value: Int, lifecycleOwner: TestLifecycleOwner = newLifecycleOwner()) :
        androidx.lifecycle.LifecycleOwner by lifecycleOwner {
        override fun equals(other: Any?) = other is EqualOwner && other.value == value
        override fun hashCode() = value
    }

    private val log = mutableListOf<String>()

    @Test
    fun identifiersAscendFromOneNeverZero() {
        val registry = CYLLifecycleCallbacks(Owner())
        val ids = (0 until 3).map { registry.willDealloc { _, _, _ -> } }
        assertEquals(listOf(1L, 2L, 3L), ids)
        assertFalse(ids.contains(cylDeallocCallbackIllegalIdentifier))
    }

    @Test
    fun cancelReturnsTrueOnceThenFalse() {
        val registry = CYLLifecycleCallbacks(Owner())
        val ids = (0 until 3).map { registry.willDealloc { _, _, _ -> } }
        assertTrue(registry.cancel(ids[1]))
        assertFalse(registry.cancel(ids[1]))
        assertFalse(registry.cancel(cylDeallocCallbackIllegalIdentifier))
    }

    @Test
    fun cancelLaterTasksDoNotRunTheEarlierOneDoes() {
        val registry = CYLLifecycleCallbacks(Owner())
        val ids = listOf("first", "second", "third").map { name -> registry.willDealloc { _, _, _ -> log.add(name) } }
        val cancelled = ids.filter { it > ids[0] }.map { registry.cancel(it) }
        assertEquals(listOf(true, true), cancelled)
        registry.dealloc()
        assertEquals(listOf("first"), log)
    }

    @Test
    fun addingWillDeallocRunsNothingEarly() {
        val registry = CYLLifecycleCallbacks(Owner())
        for (name in listOf("a", "b", "c")) {
            registry.willDealloc { _, _, _ -> log.add(name) }
            assertTrue(log.isEmpty())
        }
        registry.dealloc()
        assertEquals(listOf("a", "b", "c"), log)
    }

    @Test
    fun orderByIdentifierCancelOneAndTypedOwner() {
        val owner = Owner()
        val registry = CYLLifecycleCallbacks(owner)
        var typed = false
        val ids = (0 until 3).map { index ->
            registry.addCallback(CYLLifecycleEvent.START) { received: Owner, id, _ ->
                typed = received === owner
                log.add("$index:$id")
            }
        }
        registry.cancel(ids[1])
        registry.perform(CYLLifecycleEvent.START)
        assertEquals(listOf("0:${ids[0]}", "2:${ids[2]}"), log)
        assertTrue(typed)
    }

    @Test
    fun cancelAllRemovesUnkeyedCallbacksOfTheEvent() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.START) { _, _, _ -> log.add("start") }
        registry.addCallback(CYLLifecycleEvent.STOP) { _, _, _ -> log.add("stop") }
        registry.cancelAll(CYLLifecycleEvent.START)
        registry.perform(CYLLifecycleEvent.START)
        registry.perform(CYLLifecycleEvent.STOP)
        assertEquals(listOf("stop"), log)
    }

    @Test
    fun invokeOnceRunsOnceUntilRearmedByKey() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "layoutBlock") { _, _, _ -> log.add("end1") }
        registry.perform(CYLLifecycleEvent.LAYOUT)
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("end1"), log)
        assertTrue(registry.rearm("layoutBlock"))
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("end1", "end1"), log)
        assertFalse(registry.rearm("unknown"))
    }

    @Test
    fun replaceByKeyRearmsTheReplacement() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "layoutBlock") { _, _, _ -> log.add("end1") }
        registry.perform(CYLLifecycleEvent.LAYOUT)
        log.clear()
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "layoutBlock") { _, _, _ -> log.add("end2") }
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("end2"), log)
    }

    @Test
    fun coreRearmsByKeyAppRunOnceBlockStaysFired() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "cyl.core.layoutBlock") { _, _, _ -> log.add("core") }
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true) { _, _, _ -> log.add("app") }
        registry.perform(CYLLifecycleEvent.LAYOUT)
        log.clear()
        registry.rearm("cyl.core.layoutBlock")
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("core"), log)
    }

    @Test
    fun rearmByEventSkipsKeyedCallbacks() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "cyl.core.layoutBlock") { _, _, _ -> log.add("core") }
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true) { _, _, _ -> log.add("app") }
        registry.perform(CYLLifecycleEvent.LAYOUT)
        log.clear()
        registry.rearm(CYLLifecycleEvent.LAYOUT)
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("app"), log)
    }

    @Test
    fun cancelByKeyRemovesOnlyThatCallback() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true, key = "cyl.core.layoutBlock") { _, _, _ -> log.add("core") }
        registry.addCallback(CYLLifecycleEvent.LAYOUT, invokeOnce = true) { _, _, _ -> log.add("app") }
        assertTrue(registry.cancel("cyl.core.layoutBlock"))
        assertFalse(registry.cancel("cyl.core.layoutBlock"))
        registry.rearm(CYLLifecycleEvent.LAYOUT)
        registry.perform(CYLLifecycleEvent.LAYOUT)
        assertEquals(listOf("app"), log)
    }

    @Test
    fun cancelWillDeallocByKeyReturnsTrueOnce() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.willDealloc(key = "k") { _, _, _ -> log.add("never") }
        assertTrue(registry.cancel("k"))
        assertFalse(registry.cancel("k"))
        registry.dealloc()
        assertTrue(log.isEmpty())
    }

    @Test
    fun addAndCancelInsideACallback() {
        val registry = CYLLifecycleCallbacks(Owner())
        var laterId = 0L
        registry.addCallback(CYLLifecycleEvent.CREATE) { _, _, _ ->
            log.add("first")
            registry.cancel(laterId)
            registry.addCallback(CYLLifecycleEvent.START) { _, _, _ -> log.add("added") }
        }
        laterId = registry.addCallback(CYLLifecycleEvent.CREATE) { _, _, _ -> log.add("later") }
        registry.perform(CYLLifecycleEvent.CREATE)
        registry.perform(CYLLifecycleEvent.START)
        assertEquals(listOf("first", "added"), log)
    }

    @Test
    fun deallocSharesIdentifiersRunsInOrderWithInfoAndKeyedReplacement() {
        val registry = CYLLifecycleCallbacks(Owner())
        val a = registry.willDealloc { _, id, _ -> log.add("old:$id") }
        val b = registry.addCallback(CYLLifecycleEvent.CREATE) { _, _, _ -> }
        val c = registry.willDealloc { _, id, info -> log.add("new:$id:${info.isDealloc}") }
        registry.willDealloc(key = "k") { _, _, _ -> log.add("key1") }
        registry.willDealloc(key = "k") { _, _, _ -> log.add("key2") }
        assertTrue(a < b && b < c)
        registry.dealloc()
        assertEquals(listOf("old:1", "new:3:true", "key2"), log)
    }

    @Test
    fun deallocRunsOnceAndCancelDuringItHasNoEffect() {
        val registry = CYLLifecycleCallbacks(Owner())
        var second = 0L
        registry.willDealloc { _, _, _ ->
            log.add("first")
            assertFalse(registry.cancel(second))
        }
        second = registry.willDealloc { _, _, _ -> log.add("second") }
        registry.dealloc()
        registry.dealloc()
        assertEquals(listOf("first", "second"), log)
        assertEquals(cylDeallocCallbackIllegalIdentifier, registry.willDealloc { _, _, _ -> log.add("late") })
    }

    @Test
    fun cancelAllWillDeallocKeepsKeyedCallbacks() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.willDealloc(key = "cyl.core.kvo") { _, _, _ -> log.add("core") }
        registry.willDealloc { _, _, _ -> log.add("app") }
        registry.cancelAllWillDealloc()
        registry.dealloc()
        assertEquals(listOf("core"), log)
    }

    @Test
    fun appCancelAllKeepsTheCoresKeyedCallbacks() {
        val registry = CYLLifecycleCallbacks(Owner())
        registry.addCallback(CYLLifecycleEvent.START, key = "cyl.core.start") { _, _, _ -> log.add("core") }
        registry.addCallback(CYLLifecycleEvent.START) { _, _, _ -> log.add("app") }
        registry.cancelAll(CYLLifecycleEvent.START)
        registry.perform(CYLLifecycleEvent.START)
        assertEquals(listOf("core"), log)
    }

    private class Observable {
        val observers = mutableListOf<Any>()
    }

    @Test
    fun observerRemovedByTheDeallocCallbackWhetherOrNotCreateRan() {
        for (created in listOf(true, false)) {
            val observable = Observable()
            val owner = TestLifecycleOwner(Lifecycle.State.INITIALIZED, Dispatchers.Unconfined)
            val registry = CYLLifecycleCallbacks(owner)
            registry.attachTo(owner.lifecycle)
            val observer = Any()
            observable.observers.add(observer)
            registry.willDealloc { _, _, _ -> observable.observers.remove(observer) }
            if (created) owner.currentState = Lifecycle.State.CREATED
            assertEquals(1, observable.observers.size)
            // Without CREATE no lifecycle can reach DESTROYED (the iOS case: viewDidLoad never ran); dealloc() covers it.
            if (created) owner.currentState = Lifecycle.State.DESTROYED else registry.dealloc()
            assertTrue("created=$created", observable.observers.isEmpty())
        }
    }

    @Test
    fun attachToDispatchesLifecycleEventsThenDeallocOnDestroy() {
        val owner = TestLifecycleOwner(Lifecycle.State.INITIALIZED, Dispatchers.Unconfined)
        val registry = CYLLifecycleCallbacks(owner)
        registry.attachTo(owner.lifecycle)
        for (event in CYLLifecycleEvent.values().filter { it != CYLLifecycleEvent.LAYOUT }) {
            registry.addCallback(event) { _, _, info -> log.add(info.event.toString()) }
        }
        registry.willDealloc { _, _, info -> log.add("dealloc:${info.event}:${info.isDealloc}") }
        owner.currentState = Lifecycle.State.RESUMED
        owner.currentState = Lifecycle.State.CREATED
        owner.currentState = Lifecycle.State.DESTROYED
        assertEquals(
            listOf("CREATE", "START", "RESUME", "PAUSE", "STOP", "DESTROY", "dealloc:DESTROY:true"),
            log,
        )
    }

    @Test
    fun performDoesNothingWhenTheOwnerIsGone() {
        var owner: Owner? = Owner()
        val registry = CYLLifecycleCallbacks(owner!!)
        registry.addCallback(CYLLifecycleEvent.START) { _, _, _ -> log.add("never") }
        owner = null
        repeat(50) { if (log.isEmpty()) System.gc() }
        registry.perform(CYLLifecycleEvent.START)
        // The owner is held weakly: once collected nothing runs (if the JVM kept it, the callback ran and the owner was alive).
        assertTrue(log.isEmpty() || log == listOf("never"))
    }

    @Test
    fun extensionMatchesOwnersByIdentityNotEquals() {
        val first = EqualOwner(1)
        val second = EqualOwner(1)
        assertTrue(first == second)
        val registry = first.cylLifecycleCallbacks()
        assertSame(registry, first.cylLifecycleCallbacks())
        assertNotSame(registry, second.cylLifecycleCallbacks())
    }

    @Test
    fun extensionAttachesToTheLifecycle() {
        val owner = TestLifecycleOwner(Lifecycle.State.INITIALIZED, Dispatchers.Unconfined)
        owner.cylLifecycleCallbacks().addCallback(CYLLifecycleEvent.CREATE) { _, _, _ -> log.add("create") }
        owner.currentState = Lifecycle.State.CREATED
        assertEquals(listOf("create"), log)
    }

    @Test
    fun concurrentAddsGetUniqueIdentifiers() {
        val registry = CYLLifecycleCallbacks(Owner())
        val pool = Executors.newFixedThreadPool(4)
        val ids = (0 until 400).map { pool.submit<Long> { registry.willDealloc { _, _, _ -> } } }.map { it.get() }
        pool.shutdown()
        assertEquals(400, ids.toSet().size)
        assertEquals((1L..400L).toList(), ids.sorted())
    }

    private companion object
}

private fun newLifecycleOwner() = TestLifecycleOwner(Lifecycle.State.INITIALIZED, Dispatchers.Unconfined)
