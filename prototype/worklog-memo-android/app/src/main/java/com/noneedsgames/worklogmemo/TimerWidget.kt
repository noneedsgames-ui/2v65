package com.noneedsgames.worklogmemo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ホーム画面のウィジェット。止まっているときは「ストップウォッチ」「タイマー」のボタン、
 * 計っているときは経過時間(タイマーは終わる時刻)と「止める」を出す。
 * ボタンはアプリを開き、画面(index.html)の window.onWidget に始める・止めるを伝える。
 * タイマーの様子は、画面から Android.timerState で受け取って覚えておく
 */
class TimerWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = views(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }

    companion object {
        const val ACTION = "com.noneedsgames.worklogmemo.WIDGET"
        const val EXTRA = "widget_action"
        val ACTIONS = setOf("stopwatch", "pomodoro", "stop", "show", "plan", "prefs")
        const val PREFS = "timer_widget"

        fun saveState(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("state", json).commit()
            refresh(context)
            TimerNotice.refresh(context)
            Alarms.schedule(context)
        }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TimerWidget::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
        }

        fun open(context: Context, action: String, request: Int): PendingIntent {
            val i = Intent(context, MainActivity::class.java)
                .setAction(ACTION)
                .putExtra(EXTRA, action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        private fun views(context: Context): RemoteViews {
            val st = try {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("state", null)?.let { JSONObject(it) }
            } catch (_: Exception) { null }
            val running = st?.optBoolean("running") == true
            val v = RemoteViews(context.packageName, R.layout.widget_timer)
            v.setViewVisibility(R.id.w_idle, if (running) View.GONE else View.VISIBLE)
            v.setViewVisibility(R.id.w_run, if (running) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(R.id.w_sw, open(context, "stopwatch", 1))
            v.setOnClickPendingIntent(R.id.w_pomo, open(context, "pomodoro", 2))
            v.setOnClickPendingIntent(R.id.w_stop, open(context, "stop", 3))
            v.setOnClickPendingIntent(R.id.w_info, open(context, "show", 4))
            if (running && st != null) {
                val type = st.optString("type").takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""
                if (st.optString("mode") == "pomodoro") {
                    val ph = Alarms.phaseAt(st, System.currentTimeMillis())
                    val end = ph?.end ?: st.optLong("phaseEnd")
                    val phase = if ((ph?.phase ?: st.optString("phase")) == "break") "休憩" else "集中"
                    val at = if (end > 0) SimpleDateFormat("H:mm", Locale.JAPAN).format(Date(end)) else ""
                    v.setTextViewText(R.id.w_title, "タイマー$type")
                    v.setViewVisibility(R.id.w_chrono, View.GONE)
                    v.setViewVisibility(R.id.w_until, View.VISIBLE)
                    v.setTextViewText(R.id.w_until, "$phase 〜$at")
                    v.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime(), null, false)
                } else {
                    // 端末の起動からの時刻に直して、ウィジェットの中で秒を進める
                    val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - st.optLong("start"))
                    v.setTextViewText(R.id.w_title, "ストップウォッチ$type")
                    v.setViewVisibility(R.id.w_until, View.GONE)
                    v.setViewVisibility(R.id.w_chrono, View.VISIBLE)
                    v.setChronometer(R.id.w_chrono, base, null, true)
                }
            } else {
                v.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime(), null, false)
            }
            return v
        }
    }
}
