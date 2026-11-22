package com.chenyilong.cyldeallocblockexecutor

import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent.viewDidLayoutSubviews as e
import com.chenyilong.cyldeallocblockexecutor.LifecycleTiming.afterSuper
import com.chenyilong.cyldeallocblockexecutor.LifecycleTiming.beforeSuper
import com.chenyilong.cyldeallocblockexecutor.LifecycleTiming.end
import java.util.concurrent.CountDownLatch
import kotlin.concurrent.thread
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertSame
import kotlin.test.assertTrue

class LifecycleRegistryTest {
    private lateinit var owner: Any
    private lateinit var r: LifecycleRegistry
    private val log = mutableListOf<String>()

    @BeforeTest
    fun setUp() {
        owner = Any()
        r = LifecycleRegistry.of(owner)
        log.clear()
    }

    private fun fire(t: LifecycleTiming = end) {
        r.setManualLifecycleDispatch(true, setOf(e))
        r.invokeLifecycleCallbacks(e, t)
    }

    @Test fun oneRegistryPerOwner() = assertSame(r, LifecycleRegistry.of(owner))

    @Test fun orderByIdentifierOwnerAndIdentifierInEveryBlockTypedOwner() {
        val a = r.addLifecycleCallback<Any>(e, end) { o, id, _ -> assertSame(owner, o); log += "a$id" }
        val b = r.addLifecycleCallback<Any>(e, end) { _, id, _ -> log += "b$id" }
        assertTrue(b > a)
        fire()
        assertEquals(listOf("a$a", "b$b"), log)
    }

    @Test fun cancelOneByIdentifierAndByKeyUnknownIsFalse() {
        val a = r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "a" }
        r.addLifecycleCallback<Any>(e, end, key = "k") { _, _, _ -> log += "b" }
        r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "c" }
        assertTrue(r.cancelLifecycleCallback(identifier = a))
        assertFalse(r.cancelLifecycleCallback(identifier = a))
        assertTrue(r.cancelLifecycleCallback(key = "k"))
        fire()
        assertEquals(listOf("c"), log)
    }

    @Test fun cancelAllByEventAndTiming() {
        r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "end" }
        r.addLifecycleCallback<Any>(e) { _, _, _ -> log += "after" }
        r.cancelAllLifecycleCallbacks(e, end)
        fire(); fire(afterSuper)
        assertEquals(listOf("after"), log)
    }

    @Test fun invokeOnceThenRearm() {
        r.addLifecycleCallback<Any>(e, end, invokeOnce = true) { _, _, _ -> log += "once" }
        fire(); fire()
        assertEquals(listOf("once"), log)
        r.rearmLifecycleCallbacks(e)
        fire()
        assertEquals(listOf("once", "once"), log)
    }

    @Test fun replaceByKeyStartsUnfiredAndKeepsOneBlock() {
        val key = "cyl.core.layoutBlock"
        r.addLifecycleCallback<Any>(e, end, invokeOnce = true, key = key) { _, _, _ -> log += "old" }
        fire()
        r.addLifecycleCallback<Any>(e, end, invokeOnce = true, key = key) { _, _, _ -> log += "new" }
        fire(); fire()
        assertEquals(listOf("old", "new"), log)
        assertEquals(1, r.blockCount)
    }

    @Test fun isolationCancelAllAndRearmByEventSkipKeyedBlocks() {
        r.addLifecycleCallback<Any>(e, end, invokeOnce = true, key = "cyl.core.x") { _, _, _ -> log += "core" }
        r.addLifecycleCallback<Any>(e, end, invokeOnce = true) { _, _, _ -> log += "app" }
        fire()
        r.rearmLifecycleCallbacks(e)
        fire()
        assertEquals(listOf("core", "app", "app"), log)
        r.cancelAllLifecycleCallbacks(e)
        assertEquals(1, r.blockCount)
        r.rearmLifecycleCallback("cyl.core.x")
        fire()
        assertEquals("core", log.last())
    }

    @Test fun addAndCancelFromInsideABlock() {
        var second = 0
        r.addLifecycleCallback<Any>(e, end) { _, _, _ ->
            log += "first"
            r.cancelLifecycleCallback(identifier = second)
            r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "added" }
        }
        second = r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "second" }
        fire()
        assertEquals(listOf("first"), log)
        fire()
        assertEquals(listOf("first", "first", "added"), log)
    }

    @Test fun infoCarriesEventAndTiming() {
        r.addLifecycleCallback<Any>(e, end) { _, _, i -> log += "${i.event}/${i.timing}" }
        fire()
        assertEquals(listOf("viewDidLayoutSubviews/end"), log)
    }

    @Test fun performWithoutAHookFiresAllTimingsOnceAtTheOutermost() {
        for (t in LifecycleTiming.values()) r.addLifecycleCallback<Any>(e, t) { _, _, _ -> log += t.name }
        r.performLifecycle(e, callSuper = {
            log += "super"
            r.performLifecycle(e, callSuper = { log += "inner super" }, body = { log += "inner body" })
        }, body = { log += "body" })
        assertEquals(listOf("beforeSuper", "super", "inner super", "inner body", "afterSuper", "body", "end"), log)
    }

    @Test fun performWithAHookAddsOnlyEnd() {
        r.hookInstalled = true
        for (t in LifecycleTiming.values()) r.addLifecycleCallback<Any>(e, t) { _, _, _ -> log += t.name }
        r.performLifecycle(e, callSuper = { log += "super" }, body = { log += "body" })
        assertEquals(listOf("super", "body", "end"), log)
    }

    @Test fun manualPerTimingTheHookSkipsOnlyTheDeclaredTiming() {
        r.hookInstalled = true
        r.setManualLifecycleDispatch(true, setOf(e), setOf(end))
        assertTrue(r.isAutomatic(e, afterSuper))
        assertFalse(r.isAutomatic(e, end))
        r.addLifecycleCallback<Any>(e, end) { _, _, _ -> log += "end" }
        r.performLifecycle(e, callSuper = {}, body = {})
        assertEquals(emptyList(), log)
        r.invokeLifecycleCallbacks(e, end)
        assertEquals(listOf("end"), log)
    }

    @Test fun rawInvokeNeedsTheEventDeclaredManual() {
        assertFailsWith<IllegalStateException> { r.invokeLifecycleCallbacks(e, end) }
    }

    @Test fun deallocOrderOnceSharedIdentifiersKeyedReplacement() {
        val a = r.addDeallocCallback<Any> { _, id, i -> assertTrue(i.isDealloc); log += "a$id" }
        val l = r.addLifecycleCallback<Any>(e, end) { _, _, _ -> }
        r.addDeallocCallback<Any>(key = "k") { _, _, _ -> log += "old" }
        r.addDeallocCallback<Any>(key = "k") { _, _, _ -> log += "new" }
        assertEquals(a + 1, l)
        r.runDealloc(); r.runDealloc()
        assertEquals(listOf("a$a", "new"), log)
    }

    @Test fun deallocIsolationCancelAllKeepsKeyedCancelByKeyRemovesIt() {
        r.addDeallocCallback<Any> { _, _, _ -> log += "app" }
        r.addDeallocCallback<Any>(key = "cyl.core.kvo") { _, _, _ -> log += "core" }
        r.cancelAllDeallocCallbacks()
        r.runDealloc()
        assertEquals(listOf("core"), log)
        log.clear()
        r.addDeallocCallback<Any>(key = "cyl.core.kvo") { _, _, _ -> log += "core2" }
        assertTrue(r.cancelDeallocCallback(key = "cyl.core.kvo"))
        r.runDealloc()
        assertEquals(emptyList(), log)
    }

    @Test fun sharedLockIdentifiersAreUniqueAcrossThreads() {
        val ids = java.util.Collections.synchronizedList(mutableListOf<Int>())
        val start = CountDownLatch(1)
        val threads = (1..8).map {
            thread {
                start.await()
                repeat(200) { ids += r.addLifecycleCallback<Any>(e, end) { _, _, _ -> } }
            }
        }
        start.countDown()
        threads.forEach { it.join() }
        assertEquals(1600, ids.toSet().size)
        assertEquals(1600, r.blockCount)
    }
}
