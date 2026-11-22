package com.cyl.deallocblockexecutor

/**
 * The identifier no callback ever gets (0).
 */
const val cylDeallocCallbackIllegalIdentifier: Long = 0L

/**
 * What a callback is told about the event.
 *
 * @property event the event of this run; for a willDealloc callback run by DESTROY it is DESTROY, for an explicit dealloc it is null.
 * @property isDealloc true for a willDealloc callback.
 * @property extras arguments of a manual dispatch, free for the owner to define.
 */
data class CYLLifecycleInfo(
    val event: CYLLifecycleEvent? = null,
    val isDealloc: Boolean = false,
    val extras: Map<String, Any?> = emptyMap(),
)
