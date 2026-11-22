package com.cyl.deallocblockexecutor

/**
 * The events a callback can wait for. The first six map to androidx Lifecycle.Event; LAYOUT has no counterpart in
 * Lifecycle and is dispatched by the owner with perform (the counterpart of viewDidLayoutSubviews on iOS).
 */
enum class CYLLifecycleEvent {
    /**
     * Lifecycle.Event.ON_CREATE (iOS: viewDidLoad).
     */
    CREATE,

    /**
     * Lifecycle.Event.ON_START (iOS: viewWillAppear).
     */
    START,

    /**
     * Lifecycle.Event.ON_RESUME (iOS: viewDidAppear).
     */
    RESUME,

    /**
     * Lifecycle.Event.ON_PAUSE (iOS: viewWillDisappear).
     */
    PAUSE,

    /**
     * Lifecycle.Event.ON_STOP (iOS: viewDidDisappear).
     */
    STOP,

    /**
     * Lifecycle.Event.ON_DESTROY. The registry also runs the willDealloc callbacks after the DESTROY callbacks.
     */
    DESTROY,

    /**
     * Manual only: the owner calls perform(LAYOUT) after it laid out its children (iOS: viewDidLayoutSubviews).
     */
    LAYOUT,
}
