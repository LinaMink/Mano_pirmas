package com.example.lock_screen_love

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.lock_screen_love/widget"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, 
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    // Siųsti intent widget'ui
                    val intent = Intent(this, HomeWidgetProvider::class.java)
                    intent.action = "UPDATE_WIDGET"
                    sendBroadcast(intent)
                    
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}