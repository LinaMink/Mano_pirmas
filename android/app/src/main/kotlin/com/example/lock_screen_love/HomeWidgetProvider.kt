package com.example.lock_screen_love

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import java.text.SimpleDateFormat
import java.util.*

class HomeWidgetProvider : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d("LoveWidget", "🔄 Widget updating...")
        
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.home_widget)
        
        // 🎯 GAUTI IŠ SHAREDPREFERENCES
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )
        
        // Gauti žinutę
        var message = prefs.getString("flutter.daily_message", null)
        if (message == null) {
            message = prefs.getString("daily_message", "Kraunama...")
        }
        
        // Gauti rašytojo vardą
        var writer = prefs.getString("flutter.writer_name", null)
        if (writer == null) {
            writer = prefs.getString("writer_name", "")
        }
        
        Log.d("LoveWidget", "📝 Message: ${message?.take(20)}...")
        Log.d("LoveWidget", "👤 Writer: $writer")
        
        // 📅 GAUTI DATĄ IR DIENOS NUMERĮ
        val calendar = Calendar.getInstance()
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val todayDate = dateFormat.format(Date())
        
        // 📌 SUDARYTI GALUTINĮ TEKSTĄ
        val finalText = buildWidgetText(
            message = message ?: "Tu esi nuostabus! ❤️",
            writer = writer ?: "",
            dayOfYear = dayOfYear,
            date = todayDate
        )
        
        // NUSTATYTI TEKSTĄ
        views.setTextViewText(R.id.widget_message, finalText)
        
        // PASPAUDIMAS ATIDARO PROGRAMĄ
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = android.app.PendingIntent.getActivity(
            context, 0, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or 
            android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_layout, pendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d("LoveWidget", "✅ Widget updated!")
    }
    
    /**
     * 📌 MINIMALI FUNKCIJA - sudaro widget teksta
     */
    private fun buildWidgetText(
        message: String,
        writer: String,
        dayOfYear: Int,
        date: String
    ): String {
        // Jei yra rašytojo vardas - pridėti jį
        return if (writer.isNotEmpty()) {
            "📅 $date (diena $dayOfYear)\n" +
            "👤 $writer žinutė:\n" +
            "\"$message\""
        } else {
            "📅 $date (diena $dayOfYear)\n" +
            "❤️ Šios dienos žinutė:\n" +
            "\"$message\""
        }
    }
}