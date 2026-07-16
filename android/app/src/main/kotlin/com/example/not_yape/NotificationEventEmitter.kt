package com.example.not_yape

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object NotificationEventEmitter {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun setSink(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun clearSink() {
        sink = null
    }

    fun emit(payload: Map<String, Any?>) {
        val current = sink ?: return
        mainHandler.post {
            current.success(payload)
        }
    }
}
