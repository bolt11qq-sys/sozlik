package uz.sozlik.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Bosh ekran vidjeti: bugun nechta so'z kutayotgani.
 * Ilova keyingi 7 kun prognozini yozib qo'yadi, vidjet esa mantiqiy kunni
 * (kun almashish soati bilan) o'zi hisoblab, kerakli sonni ko'rsatadi.
 */
class SozlikWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val startHour = widgetData.getString("dayStartHour", "4")?.toIntOrNull() ?: 4
        val cal = Calendar.getInstance().apply { add(Calendar.HOUR_OF_DAY, -startHour) }
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

        val savedDay = widgetData.getString("today", null)
        val forecast = (widgetData.getString("forecast", "") ?: "")
            .split(";")
            .mapNotNull { part ->
                val kv = part.split("=")
                if (kv.size == 2) kv[0] to (kv[1].toIntOrNull() ?: 0) else null
            }
            .toMap()

        val count: Int?
        val sub: String
        if (savedDay == today) {
            count = widgetData.getString("remaining", "0")?.toIntOrNull() ?: 0
            val done = widgetData.getString("done", "0")?.toIntOrNull() ?: 0
            sub = if (count == 0) "Bugungi reja bajarildi" else "ta so'z kutmoqda · $done bajarildi"
        } else if (forecast.containsKey(today)) {
            count = forecast[today]
            sub = if (count == 0) "Bugun takrorlash yo'q" else "ta so'z kutmoqda"
        } else {
            count = null
            sub = "Ilovani oching"
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sozlik_widget).apply {
                setTextViewText(R.id.widget_count, count?.toString() ?: "—")
                setTextViewText(R.id.widget_sub, sub)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
