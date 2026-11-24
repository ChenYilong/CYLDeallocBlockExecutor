package com.chenyilong.cyldeallocblockexecutor.example

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.chenyilong.cyldeallocblockexecutor.LifecycleCenter
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.binding.AndroidBinding
import com.chenyilong.cyldeallocblockexecutor.binding.observeScrolling

/**
 * A fragment with a RecyclerView inside a FragmentActivity: logs the fragment events and the scroll events (logcat tag CYL),
 * and counts the global pause / resume of `LifecycleCenter.whileUserScrolls` (a flick must end with pauses == resumes).
 */
class ListActivity : FragmentActivity() {

    class ListFragment : Fragment() {
        private var count = 0
        private var stopObserving: (() -> Unit)? = null

        override fun onAttach(context: android.content.Context) {
            // Blocks must be added before the binding fires the fragment's first events.
            val registry = AndroidBinding.controllerOf(this).registry
            for (e in LifecycleEvent.values()) {
                registry.addLifecycleCallback<Any>(e) { _, _, _ -> count += 1; Log.i("CYL", "FRAGMENT $count ${e.name}") }
            }
            registry.addDeallocCallback<Any> { _, _, _ -> Log.i("CYL", "FRAGMENT teardown") }
            super.onAttach(context)
        }

        override fun onCreateView(i: LayoutInflater, c: ViewGroup?, s: Bundle?): View {
            val rv = RecyclerView(requireContext())
            rv.layoutManager = LinearLayoutManager(requireContext())
            rv.adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
                override fun onCreateViewHolder(p: ViewGroup, t: Int) = object : RecyclerView.ViewHolder(
                    TextView(p.context).apply { textSize = 22f; setPadding(32, 48, 32, 48) }
                ) {}
                override fun onBindViewHolder(h: RecyclerView.ViewHolder, pos: Int) { (h.itemView as TextView).text = "row $pos" }
                override fun getItemCount() = 400
            }
            stopObserving = AndroidBinding.observeScrolling(this, rv)
            return FrameLayout(requireContext()).apply { addView(rv) }
        }

        override fun onDestroyView() {
            stopObserving?.invoke()
            super.onDestroyView()
        }
    }

    private var pauses = 0
    private var resumes = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // Activity events (dark mode, rotation, memory trim) logged with the prefix ACT; blocks go in before super.onCreate.
        var actCount = 0
        val registry = AndroidBinding.controllerOf(this).registry
        for (e in LifecycleEvent.values()) {
            registry.addLifecycleCallback<Any>(e) { _, _, _ ->
                actCount += 1
                if (!e.name.endsWith("Subviews")) Log.i("CYL", "ACT $actCount ${e.name}")
            }
        }
        super.onCreate(savedInstanceState)
        LifecycleCenter.whileUserScrolls(
            pause = { pauses += 1; Log.i("CYL", "SCROLLCOUNT pauses=$pauses resumes=$resumes") },
            resume = { resumes += 1; Log.i("CYL", "SCROLLCOUNT pauses=$pauses resumes=$resumes") },
        )
        val host = FrameLayout(this).apply { id = 0x7f0a0002; setPadding(0, 120, 0, 0) }
        setContentView(host)
        supportFragmentManager.beginTransaction().replace(host.id, ListFragment()).commit()
    }
}
