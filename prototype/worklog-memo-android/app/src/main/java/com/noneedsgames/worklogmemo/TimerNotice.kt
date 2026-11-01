package com.noneedsgames.worklogmemo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ロック画面にも出る通知。止まっているときは「ストップウォッチ」、計っているときは経過と「止める」を出す。
 * ボタンはアプリを開かずに(ロックを解かずに)効く。記録は画面側でつけるので、
 * 押した時刻を出来事として貯めておき、画面が動いたら takeEvents で渡す
 */
object TimerNotice {
    private const val CHANNEL = "timer_control"
    private const val NOTE_ID = 2
    private const val BLOCK_MIN = 5
    const val ACTION_START = "com.noneedsgames.worklogmemo.NOTICE_START"
    const val ACTION_STOP = "com.noneedsgames.worklogmemo.NOTICE_STOP"

    private fun prefs(c: Context) = c.getSharedPreferences(TimerWidget.PREFS, Context.MODE_PRIVATE)

    fun setEnabled(c: Context, on: Boolean) {
        prefs(c).edit().putBoolean("notice", on).apply()
        refresh(c)
    }

    /** 通知から始めるときにブロックする妨害アプリ(JSON配列)。ブロックを切っていれば空 */
    fun setBlockApps(c: Context, json: String) { prefs(c).edit().putString("blockApps", json).apply() }

    fun hasEvents(c: Context) = prefs(c).getString("events", null) != null

    fun takeEvents(c: Context): String {
        val p = prefs(c)
        synchronized(this) {
            val s = p.getString("events", null) ?: return "[]"
            p.edit().remove("events").commit()
            return s
        }
    }

    /** 通知のボタンが押されたとき:出来事を貯め、通知とウィジェットの表示を先に変える */
    fun press(c: Context, action: String) {
        val p = prefs(c)
        val st = try { p.getString("state", null)?.let { JSONObject(it) } } catch (_: Exception) { null } ?: JSONObject()
        val running = st.optBoolean("running")
        if (running == (action == ACTION_START)) { refresh(c); return } // 二度押しは何もしない
        val now = System.currentTimeMillis()
        synchronized(this) {
            val ev = try { JSONArray(p.getString("events", null) ?: "[]") } catch (_: Exception) { JSONArray() }
            ev.put(JSONObject().put("a", if (action == ACTION_START) "start" else "stop").put("t", now))
            p.edit().putString("events", ev.toString()).commit()
        }
        st.put("running", !running)
        if (action == ACTION_START) st.put("mode", "stopwatch").put("start", now).put("warn", startBlock(c))
        else BlockService.stop(c)
        TimerWidget.saveState(c, st.toString())
    }

    fun refresh(c: Context) {
        val nm = c.getSystemService(NotificationManager::class.java)
        if (!prefs(c).getBoolean("notice", false)) { nm.cancel(NOTE_ID); return }
        // 「サイレント」の重要度だとロック画面に出さない端末が多いので、通常の重要度で音と振動だけを消す
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "ロック画面のタイマー", NotificationManager.IMPORTANCE_DEFAULT).apply {
            setSound(null, null); enableVibration(false); setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        })
        nm.notify(NOTE_ID, build(c))
    }

    private fun build(c: Context): Notification {
        val st = try { prefs(c).getString("state", null)?.let { JSONObject(it) } } catch (_: Exception) { null }
        val running = st?.optBoolean("running") == true
        val v = RemoteViews(c.packageName, R.layout.notice_timer)
        val pomodoro = st?.optString("mode") == "pomodoro"
        val title: String
        if (running && st != null && !pomodoro) {
            title = "ストップウォッチ"
            // 端末の起動からの時刻に直して、通知の中で秒を進める
            val base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - st.optLong("start"))
            v.setChronometer(R.id.n_chrono, base, null, true)
            v.setViewVisibility(R.id.n_big, View.GONE)
        } else {
            v.setChronometer(R.id.n_chrono, SystemClock.elapsedRealtime(), null, false)
            v.setViewVisibility(R.id.n_chrono, View.GONE)
            title = if (running && st != null) {
                val end = st.optLong("phaseEnd")
                val phase = if (st.optString("phase") == "break") "休憩" else "集中"
                "$phase 〜" + (if (end > 0) SimpleDateFormat("H:mm", Locale.JAPAN).format(Date(end)) else "")
            } else "作業タイマー"
            v.setTextViewText(R.id.n_big, title)
        }
        v.setTextViewText(R.id.n_sub, if (running && st != null) st.optString("warn").ifBlank { st.optString("type") } else "")
        v.setTextViewText(R.id.n_btn, if (running) "■ 止める" else "▶ 開始")
        v.setOnClickPendingIntent(R.id.n_btn, buttonIntent(c, if (running) ACTION_STOP else ACTION_START))
        return Notification.Builder(c, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentTitle(title)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(v)
            .setCustomBigContentView(v)
            .setContentIntent(TimerWidget.open(c, "show", 5))
            .build()
    }

    private fun buttonIntent(c: Context, act: String): PendingIntent {
        val i = Intent(c, TimerNoticeReceiver::class.java).setAction(act)
        return PendingIntent.getBroadcast(c, act.hashCode(), i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** 妨害アプリのブロックを始める。ブロックするはずなのに始められなければ、通知に出す警告を返す */
    private fun startBlock(c: Context): String {
        val arr = try { JSONArray(prefs(c).getString("blockApps", null) ?: "[]") } catch (_: Exception) { JSONArray() }
        val pkgs = (0 until arr.length()).map { arr.getString(it) }
        if (pkgs.isEmpty()) return ""
        if (!UsageReader.hasAccess(c) || !Settings.canDrawOverlays(c)) return "⚠ ブロックなし(許可が必要)"
        return try { BlockService.start(c, pkgs, BLOCK_MIN); "" } catch (_: Exception) { "⚠ ブロックを始められません" }
    }
}

/** 通知のボタンと、再起動・更新のあとに通知を出し直す知らせを受ける */
class TimerNoticeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            TimerNotice.ACTION_START, TimerNotice.ACTION_STOP -> TimerNotice.press(context, intent.action!!)
            else -> TimerNotice.refresh(context)
        }
    }
}
