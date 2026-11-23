package com.chenyilong.cyldeallocblockexecutor

import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ObservableMomentsTest {
    private val owner = Any()
    private val registry = LifecycleRegistry.of(owner).also { it.hookInstalled = true }
    private val log = mutableListOf<String>()

    @BeforeTest fun reset() = LifecycleCenter.reset()
    @AfterTest fun clean() = LifecycleCenter.reset()

    @Test fun customEventsRunInIdentifierOrderWithTheNameAndUserInfo() {
        val a = registry.addCustomCallback<Any>("cyl.badge.didShow") { o, id, info -> assertTrue(o === owner); log.add("a$id ${info.customEvent} ${info.userInfo?.get("value")}") }
        val b = registry.addCustomCallback<Any>("cyl.badge.didShow") { _, id, _ -> log.add("b$id") }
        registry.postLifecycleEvent("cyl.badge.didShow", mapOf("value" to "3"))
        assertEquals(listOf("a$a cyl.badge.didShow 3", "b$b"), log)
    }

    @Test fun customEventsInvokeOnceReplaceByKeyAndCancel() {
        registry.addCustomCallback<Any>("x", invokeOnce = true) { _, _, _ -> log.add("x") }
        registry.addCustomCallback<Any>("y", key = "k") { _, _, _ -> log.add("y1") }
        registry.addCustomCallback<Any>("y", key = "k") { _, _, _ -> log.add("y2") }
        val id = registry.addCustomCallback<Any>("y") { _, _, _ -> log.add("y3") }
        registry.postLifecycleEvent("x"); registry.postLifecycleEvent("x"); registry.postLifecycleEvent("y")
        assertEquals(listOf("x", "y2", "y3"), log)
        log.clear()
        assertTrue(registry.cancelLifecycleCallback(identifier = id))
        assertTrue(registry.cancelLifecycleCallback(key = "k"))
        registry.postLifecycleEvent("y")
        assertEquals(emptyList(), log)
    }

    @Test fun customBlocksShareTheIdentifierSequenceAndRearmByKey() {
        val a = registry.addLifecycleCallback<Any>(LifecycleEvent.viewDidLoad) { _, _, _ -> }
        val b = registry.addCustomCallback<Any>("c", invokeOnce = true, key = "once") { _, _, _ -> log.add("c") }
        val c = registry.addDeallocCallback<Any> { _, _, _ -> }
        assertTrue(a < b && b < c)
        registry.postLifecycleEvent("c"); registry.postLifecycleEvent("c")
        registry.rearmLifecycleCallback("once")
        registry.postLifecycleEvent("c")
        assertEquals(listOf("c", "c"), log)
    }

    @Test fun globalObserversRunAfterTheOwnerBlocksInIdentifierOrder() {
        registry.addLifecycleCallback<Any>(LifecycleEvent.viewDidAppear) { _, _, _ -> log.add("own") }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidAppear) { o, _, info -> log.add("g1 ${o === owner} ${info.event}") }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidAppear) { _, _, _ -> log.add("g2") }
        registry.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper)
        assertEquals(listOf("own", "g1 true viewDidAppear", "g2"), log)
    }

    @Test fun globalObserversHaveTimingOwnerTypeKeyAndNeverSeeTeardown() {
        class A; class B
        val a = A()
        val ra = LifecycleRegistry.of(a).also { it.hookInstalled = true }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidLoad, ownerType = A::class) { _, _, _ -> log.add("only A") }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidLoad, LifecycleTiming.beforeSuper, key = "k") { _, _, _ -> log.add("before") }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidLoad, LifecycleTiming.beforeSuper, key = "k") { _, _, _ -> log.add("replaced") }
        ra.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.beforeSuper)
        ra.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.afterSuper)
        LifecycleRegistry.of(B()).also { it.hookInstalled = true }.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.afterSuper)
        assertEquals(listOf("replaced", "only A"), log)
        assertTrue(LifecycleCenter.cancelCallback(key = "k"))
        assertFalse(LifecycleCenter.cancelCallback(key = "k"))
        log.clear()
        ra.addDeallocCallback<Any> { _, _, _ -> log.add("own dealloc") }
        LifecycleCenter.addCallback<Any>(LifecycleEvent.viewDidLoad) { _, _, _ -> log.add("global at dealloc") }
        ra.runDealloc()
        assertEquals(listOf("own dealloc"), log)
    }

    @Test fun globalObserversSeeCustomEventsAndIsUserScrollingFollowsTheScrollEvents() {
        LifecycleCenter.addCustomCallback<Any>("cyl.badge.didShow") { o, _, info -> log.add("${o === owner} ${info.userInfo?.get("value")}") }
        registry.postLifecycleEvent("cyl.badge.didShow", mapOf("value" to "9"))
        assertEquals(listOf("true 9"), log)
        assertFalse(LifecycleCenter.isUserScrolling)
        registry.fireAutomatic(LifecycleEvent.scrollWillBeginDragging, LifecycleTiming.afterSuper)
        assertTrue(LifecycleCenter.isUserScrolling)
        registry.fireAutomatic(LifecycleEvent.scrollDidEndDragging, LifecycleTiming.afterSuper, LifecycleInfo(willDecelerate = true))
        assertTrue(LifecycleCenter.isUserScrolling)
        registry.fireAutomatic(LifecycleEvent.scrollDidEndScrolling, LifecycleTiming.afterSuper)
        assertFalse(LifecycleCenter.isUserScrolling)
    }

    @Test fun forwardingDeliversEventsToTheTargetAndAReplacementKeepsOneForward() {
        val item = Any()
        val ri = LifecycleRegistry.of(item).also { it.hookInstalled = true }
        ri.addLifecycleCallback<Any>(LifecycleEvent.didEnterScreen) { _, _, _ -> log.add("item enter") }
        ri.addLifecycleCallback<Any>(LifecycleEvent.didLeaveScreen) { _, _, _ -> log.add("item leave") }
        ri.addCustomCallback<Any>("cyl.badge.didShow") { _, _, _ -> log.add("item badge") }
        registry.forwardLifecycleEvents(ri, setOf(LifecycleEvent.didEnterScreen))
        registry.fireAutomatic(LifecycleEvent.didEnterScreen, LifecycleTiming.afterSuper)
        registry.fireAutomatic(LifecycleEvent.didLeaveScreen, LifecycleTiming.afterSuper)
        assertEquals(listOf("item enter"), log)
        log.clear()
        registry.forwardLifecycleEvents(ri)
        registry.fireAutomatic(LifecycleEvent.didLeaveScreen, LifecycleTiming.afterSuper)
        registry.postLifecycleEvent("cyl.badge.didShow")
        registry.fireAutomatic(LifecycleEvent.didEnterScreen, LifecycleTiming.afterSuper)
        assertEquals(listOf("item leave", "item badge", "item enter"), log)
    }

    @Test fun controllerReportsWindowScreenAndScrollMoments() {
        val o = Any()
        val c = LifecycleController(o)
        for (e in listOf(LifecycleEvent.willMoveToWindow, LifecycleEvent.didMoveToWindow, LifecycleEvent.didEnterScreen, LifecycleEvent.didLeaveScreen,
            LifecycleEvent.scrollWillBeginDragging, LifecycleEvent.scrollDidEndDragging, LifecycleEvent.scrollDidEndScrolling)) {
            c.registry.addLifecycleCallback<Any>(e) { _, _, info -> log.add("${e.name}${info.willDecelerate?.let { " $it" } ?: ""}${if (e == LifecycleEvent.didMoveToWindow) " ${info.window != null}" else ""}") }
        }
        c.windowMoved(true)
        c.screenVisible(true); c.screenVisible(true); c.screenVisible(false)
        c.scrollBegan(); c.scrollEndedDragging(false)
        c.scrollBegan(); c.scrollEndedDragging(true); c.scrollEnded()
        c.windowMoved(false)
        assertEquals(listOf(
            "willMoveToWindow", "didMoveToWindow true", "didEnterScreen", "didLeaveScreen",
            "scrollWillBeginDragging", "scrollDidEndDragging false", "scrollDidEndScrolling",
            "scrollWillBeginDragging", "scrollDidEndDragging true", "scrollDidEndScrolling",
            "willMoveToWindow", "didMoveToWindow false",
        ), log)
    }

    @Test fun controllerAppearEventsReportTheScreen() {
        val c = LifecycleController(Any())
        c.registry.addLifecycleCallback<Any>(LifecycleEvent.didEnterScreen) { _, _, _ -> log.add("enter") }
        c.registry.addLifecycleCallback<Any>(LifecycleEvent.didLeaveScreen) { _, _, _ -> log.add("leave") }
        c.create(); c.start(); c.resume(); c.resumedAndDrawn(); c.pause(); c.stop()
        assertEquals(listOf("enter", "leave"), log)
    }
}

class DebugLogTest {
    @kotlin.test.AfterTest fun clean() {
        LifecycleLog.enabled = false
        LifecycleLog.sink = { println(it) }
        LifecycleLog.describer = { o -> "${o?.javaClass?.simpleName}@${Integer.toHexString(System.identityHashCode(o))}" }
        LifecycleCenter.reset()
    }

    @Test fun offByDefaultAndLazyOnTheOwnersNameEventTimingAndBlockCount() {
        class Tab
        val lines = mutableListOf<String>()
        LifecycleLog.sink = { lines.add(it) }
        LifecycleLog.describer = { "Tab(tab-1)" }
        val tab = Tab()
        val r = LifecycleRegistry.of(tab).also { it.hookInstalled = true }
        r.addLifecycleCallback<Any>(LifecycleEvent.viewDidAppear) { _, _, _ -> }
        r.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper)
        assertEquals(emptyList(), lines, "disabled: nothing is built or printed")
        LifecycleLog.enabled = true
        r.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper)
        r.addCustomCallback<Any>(AnimationEvents.didPause) { _, _, _ -> }
        r.postLifecycleEvent(AnimationEvents.didPause)
        r.addDeallocCallback<Any> { _, _, _ -> }
        r.runDealloc()
        assertEquals(listOf(
            "[CYLLifecycle] Tab(tab-1) viewDidAppear/afterSuper: 1 block(s)",
            "[CYLLifecycle] Tab(tab-1) posts cyl.animation.didPause: 1 block(s)",
            "[CYLLifecycle] teardown Tab(tab-1): 1 block(s)",
            "[CYLLifecycle] dealloc Tab(tab-1)",
        ), lines)
    }

    @Test fun aDeallocObserverLearnsWhenAnyOwnerIsTornDownWithADescriptionAndNeverTheOwner() {
        val seen = mutableListOf<String>()
        LifecycleLog.describer = { "Owner(7)" }
        val id = LifecycleCenter.addDeallocObserver(key = "debug") { description, info -> seen.add("$description ${info.isDealloc}") }
        val r = LifecycleRegistry.of(Any())
        r.runDealloc()
        assertEquals(listOf("Owner(7) true"), seen)
        assertTrue(LifecycleCenter.cancelDeallocObserver(identifier = id))
        r.runDealloc()
        assertEquals(1, seen.size)
    }

    @Test fun theWellKnownEventNamesAreTheDocumentedOnes() {
        assertEquals("cyl.animation.didStart", AnimationEvents.didStart)
        assertEquals("cyl.animation.didPause", AnimationEvents.didPause)
        assertEquals("cyl.animation.didResume", AnimationEvents.didResume)
        assertEquals("cyl.animation.didStop", AnimationEvents.didStop)
        assertEquals("cyl.badge.didBecomeReady", BadgeEvents.didBecomeReady)
    }
}
