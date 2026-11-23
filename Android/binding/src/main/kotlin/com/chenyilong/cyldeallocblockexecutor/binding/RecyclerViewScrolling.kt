package com.chenyilong.cyldeallocblockexecutor.binding

import androidx.recyclerview.widget.RecyclerView

/**
 * Reports the scrolling of [recyclerView] on [owner]'s controller (design v5), without touching any listener the app set: a
 * `RecyclerView.OnScrollListener` maps the states. `SCROLL_STATE_DRAGGING` begins, `SETTLING` after dragging is the deceleration,
 * `IDLE` ends: `scrollWillBeginDragging`, `scrollDidEndDragging` (`willDecelerate`), `scrollDidEndScrolling`.
 * Add it once per scroll view; call the returned function to stop observing.
 */
fun AndroidBinding.observeScrolling(owner: Any, recyclerView: RecyclerView): () -> Unit {
    val controller = controllerOf(owner)
    val listener = object : RecyclerView.OnScrollListener() {
        private var dragging = false
        private var settling = false
        override fun onScrollStateChanged(view: RecyclerView, newState: Int) {
            when (newState) {
                RecyclerView.SCROLL_STATE_DRAGGING -> {
                    if (!dragging && !settling) controller.scrollBegan(view)
                    dragging = true
                }
                RecyclerView.SCROLL_STATE_SETTLING -> {
                    settling = true
                    if (dragging) {
                        dragging = false
                        controller.scrollEndedDragging(true, view)
                    }
                }
                RecyclerView.SCROLL_STATE_IDLE -> {
                    when {
                        dragging -> controller.scrollEndedDragging(false, view)
                        settling -> controller.scrollEnded(view)
                    }
                    dragging = false
                    settling = false
                }
            }
        }
    }
    recyclerView.addOnScrollListener(listener)
    return { recyclerView.removeOnScrollListener(listener) }
}
