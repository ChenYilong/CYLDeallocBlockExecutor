package com.chenyilong.cyldeallocblockexecutor.example

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class SecondActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply { text = "second activity (back to return)"; setPadding(24, 200, 24, 24) })
    }
}
