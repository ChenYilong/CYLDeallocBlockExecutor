package com.chenyilong.cyldeallocblockexecutor.example

import android.app.Application
import com.chenyilong.cyldeallocblockexecutor.binding.AndroidBinding

class ExampleApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AndroidBinding.install(this)
    }
}
