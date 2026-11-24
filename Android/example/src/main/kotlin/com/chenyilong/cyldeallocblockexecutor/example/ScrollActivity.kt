package com.chenyilong.cyldeallocblockexecutor.example

import android.os.Bundle
import android.util.Log
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import com.chenyilong.cyldeallocblockexecutor.LifecycleCenter
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.binding.AndroidBinding
import com.chenyilong.cyldeallocblockexecutor.binding.observeScrolling

/**
 * A plain `ScrollView` (no RecyclerView) observed with the timer-based `observeScrolling(owner, view)` overload, plus every
 * activity event (logcat tag CYL, prefix ACT) so dark mode, rotation and memory trim can be driven with adb while it is on screen.
 */
class ScrollActivity : FragmentActivity() {
    private var count = 0
    private var pauses = 0
    private var resumes = 0
    private var stopObserving: (() -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val registry = AndroidBinding.controllerOf(this).registry
        for (e in LifecycleEvent.values()) {
            registry.addLifecycleCallback<Any>(e) { _, _, _ ->
                count += 1
                if (!e.name.endsWith("Subviews")) Log.i("CYL", "ACT $count ${e.name}")
            }
        }
        registry.addDeallocCallback<Any> { _, _, _ -> Log.i("CYL", "ACT teardown") }
        super.onCreate(savedInstanceState)
        LifecycleCenter.whileUserScrolls(
            pause = { pauses += 1; Log.i("CYL", "SCROLLCOUNT pauses=$pauses resumes=$resumes") },
            resume = { resumes += 1; Log.i("CYL", "SCROLLCOUNT pauses=$pauses resumes=$resumes") },
        )
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 0, 32, 0) }
        for (i in 0 until 300) column.addView(TextView(this).apply { text = "scroll row $i"; textSize = 22f; setPadding(0, 48, 0, 48) })
        val scroll = ScrollView(this).apply { addView(column); setPadding(0, 120, 0, 0); clipToPadding = false }
        setContentView(scroll)
        scroll.post { stopObserving = AndroidBinding.observeScrolling(this, scroll) }
    }

    override fun onDestroy() {
        stopObserving?.invoke()
        super.onDestroy()
    }
}
