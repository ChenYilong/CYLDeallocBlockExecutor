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

/**
 * Reports the scrolling of any scroll container (`ScrollView`, `NestedScrollView`, `HorizontalScrollView`, a `ViewPager2` page
 * ...) on [owner]'s controller, for views that are not a `RecyclerView`. A `ViewTreeObserver.OnScrollChangedListener` is added, so no
 * listener of the app is replaced. These views do not tell dragging from settling: the first change after a pause begins
 * (`scrollWillBeginDragging`), and [idleDelayMillis] without a change ends (`scrollDidEndDragging` with `willDecelerate` false, which also
 * fires `scrollDidEndScrolling`). The view must be attached when called. Call the returned function to stop observing.
 */
fun AndroidBinding.observeScrolling(owner: Any, view: android.view.View, idleDelayMillis: Long = 150): () -> Unit {
    val controller = controllerOf(owner)
    val handler = android.os.Handler(android.os.Looper.getMainLooper())
    var scrolling = false
    val end = Runnable {
        scrolling = false
        // [EN] Without deceleration this also fires scrollDidEndScrolling. [CN] 无减速时同时触发 scrollDidEndScrolling。
        controller.scrollEndedDragging(false, view)
    }
    val listener = android.view.ViewTreeObserver.OnScrollChangedListener {
        if (!scrolling) {
            scrolling = true
            controller.scrollBegan(view)
        }
        handler.removeCallbacks(end)
        handler.postDelayed(end, idleDelayMillis)
    }
    view.viewTreeObserver.addOnScrollChangedListener(listener)
    return {
        handler.removeCallbacks(end)
        if (view.viewTreeObserver.isAlive) view.viewTreeObserver.removeOnScrollChangedListener(listener)
    }
}
