package com.chenyilong.cyldeallocblockexecutor.example

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.chenyilong.cyldeallocblockexecutor.LifecycleEvent
import com.chenyilong.cyldeallocblockexecutor.binding.AndroidBinding

/** Logs every event the binding fires for this activity (logcat tag CYL, and on screen). */
class MainActivity : FragmentActivity() {
    private lateinit var out: TextView
    private var count = 0

    private fun record(name: String) {
        count += 1
        Log.i("CYL", "EVENT $count $name")
        // Appending to a view inside a layout block would trigger another layout: keep layout events out of the screen text.
        if (::out.isInitialized && !name.endsWith("Subviews")) out.append("$count $name\n")
    }

    class Child : Fragment() {
        override fun onCreateView(i: android.view.LayoutInflater, c: ViewGroup?, s: Bundle?) =
            TextView(requireContext()).apply { text = "child fragment" }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // The binding fires `viewDidLoad` / `willMoveToParent` from `onActivityCreated`, which runs inside super.onCreate:
        // the blocks must be added before it.
        val registry = AndroidBinding.controllerOf(this).registry
        for (e in LifecycleEvent.values()) {
            registry.addLifecycleCallback<Any>(e) { _, _, _ -> record(e.name) }
        }
        registry.addDeallocCallback<Any> { _, _, _ -> Log.i("CYL", "EVENT teardown") }
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(24, 120, 24, 24); id = 0x7f0a0001 }
        root.addView(Button(this).apply {
            text = "open second activity"
            setOnClickListener { startActivity(Intent(this@MainActivity, SecondActivity::class.java)) }
        })
        root.addView(Button(this).apply {
            text = "open list (RecyclerView in a fragment)"
            setOnClickListener { startActivity(Intent(this@MainActivity, ListActivity::class.java)) }
        })
        root.addView(Button(this).apply {
            text = "open ScrollView (timer-based source)"
            setOnClickListener { startActivity(Intent(this@MainActivity, ScrollActivity::class.java)) }
        })
        root.addView(Button(this).apply {
            text = "open NestedScrollView (timer-based source)"
            setOnClickListener { startActivity(Intent(this@MainActivity, NestedScrollActivity::class.java)) }
        })
        out = TextView(this)
        root.addView(ScrollView(this).apply { addView(out) })
        setContentView(root)
    }
}
