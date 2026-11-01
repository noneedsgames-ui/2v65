package com.noneedsgames.worklogmemo

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * アプリを閉じていても届く知らせ。予定の時刻、ポモドーロの区切り、タイマーの止め忘れの三つ。
 * 目覚ましは「いちばん近い一件」だけを端末に預け、鳴ったら次を預け直す。
 * 予定は画面から setEvents で受け取り、タイマーの分は画面から受け取った様子(TimerWidget の state)から求める
 */
object Alarms {
    private const val CH_EVENT = "schedule"
    private const val CH_TIMER = "timer_alert"
    private const val ID_PHASE = 3
    private const val ID_FORGOT = 4
    private const val MISSED_LIMIT = 6 * 3600_000L // これより前に過ぎた予定は、今さら知らせない
    private const val STEP_FROM = 10 * 60_000L

    private fun prefs(c: Context) = c.getSharedPreferences(TimerWidget.PREFS, Context.MODE_PRIVATE)

    private fun state(c: Context): JSONObject? =
        try { prefs(c).getString("state", null)?.let { JSONObject(it) } } catch (_: Exception) { null }

    private fun events(c: Context): JSONArray =
        try { JSONArray(prefs(c).getString("alarms", null) ?: "[]") } catch (_: Exception) { JSONArray() }

    fun setEvents(c: Context, json: String) {
        prefs(c).edit().putString("alarms", json).apply()
        schedule(c)
    }

    class Phase(val phase: String, val start: Long, val end: Long)

    /** いまがポモドーロのどの区切りか。画面が閉じていても、始めた時刻と長さから求められる */
    fun phaseAt(st: JSONObject, now: Long): Phase? {
        val focus = st.optLong("focusMs")
        val brk = st.optLong("brkMs")
        var start = st.optLong("phaseStart")
        if (focus <= 0 || brk <= 0 || start <= 0) return null
        var phase = st.optString("phase", "focus")
        var guard = 0
        while (guard++ < 100_000) {
            val len = if (phase == "break") brk else focus
            if (now < start + len) return Phase(phase, start, start + len)
            start += len
            phase = if (phase == "break") "focus" else "break"
        }
        return null
    }

    private fun isPomodoro(st: JSONObject) = st.optBoolean("running") && st.optString("mode") == "pomodoro"

    /** 止め忘れを尋ねる時刻。尋ねない設定や止まっているときは 0 */
    private fun warnAt(st: JSONObject): Long {
        if (!st.optBoolean("running")) return 0L
        val set = st.optLong("warnAt")
        if (set > 0) return set
        val ms = st.optLong("warnMs")
        if (ms <= 0) return 0L
        val run = st.optLong("runStart").takeIf { it > 0 } ?: st.optLong("start")
        return if (run > 0) run + ms else 0L
    }

    /** まだ知らせていない区切りか。始めた直後の「集中」は区切りに数えない */
    private fun phaseUnseen(c: Context, st: JSONObject, ph: Phase) =
        ph.start > st.optLong("runStart") && ph.start > prefs(c).getLong("phaseSeen", 0L)

    private fun nextAt(c: Context, now: Long): Long? {
        var next: Long? = null
        fun take(t: Long) { if (next == null || t < next!!) next = t }
        val arr = events(c)
        for (i in 0 until arr.length()) take(arr.getJSONObject(i).optLong("at"))
        state(c)?.let { st ->
            if (isPomodoro(st)) phaseAt(st, now)?.let { ph ->
                take(ph.end)
                if (phaseUnseen(c, st, ph)) take(ph.start) // 画面の時計が先に区切りを越えても、知らせを落とさない
            }
            val w = warnAt(st)
            if (w > 0 && w != prefs(c).getLong("forgotSeen", 0L)) take(w)
        }
        return next
    }

    private fun pending(c: Context) = PendingIntent.getBroadcast(c, 77, Intent(c, AlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun canExact(c: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    /** いちばん近い時刻に目覚ましを預ける */
    fun schedule(c: Context) {
        val am = c.getSystemService(AlarmManager::class.java)
        val pi = pending(c)
        am.cancel(pi)
        val st = state(c)
        if (st == null || !st.optBoolean("running")) { // 止まったら、タイマーの知らせを片づける
            val nm = c.getSystemService(NotificationManager::class.java)
            nm.cancel(ID_PHASE); nm.cancel(ID_FORGOT)
        }
        val now = System.currentTimeMillis()
        val at = maxOf(nextAt(c, now) ?: return, now + 1000)
        try {
            if (canExact(c)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            else {
                // 許可がないと端末の都合で遅れ、遠い先ほど大きく遅れる。遠いうちは途中で起きて預け直し、遅れを小さくする
                val left = at - now
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, if (left > STEP_FROM) now + left / 2 else at, pi)
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    /** 目覚ましが鳴ったとき。アプリを前面で使っている間は、知らせは画面の側に任せる */
    fun fire(c: Context) {
        val now = System.currentTimeMillis()
        val front = MainActivity.inFront
        val p = prefs(c)
        val arr = events(c)
        val keep = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val at = o.optLong("at")
            if (at > now) keep.put(o)
            else if (!front && now - at < MISSED_LIMIT) postEvent(c, o)
        }
        p.edit().putString("alarms", keep.toString()).apply()
        state(c)?.let { st ->
            if (isPomodoro(st)) phaseAt(st, now)?.let { ph ->
                if (phaseUnseen(c, st, ph)) {
                    p.edit().putLong("phaseSeen", ph.start).apply()
                    if (!front) postPhase(c, ph)
                }
            }
            val w = warnAt(st)
            if (w in 1..now && w != p.getLong("forgotSeen", 0L)) {
                p.edit().putLong("forgotSeen", w).apply()
                if (!front) postForgot(c, st)
            }
        }
        TimerWidget.refresh(c)
        TimerNotice.refresh(c)
        schedule(c)
    }

    private fun channels(c: Context) {
        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CH_EVENT, "予定の知らせ", NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(NotificationChannel(CH_TIMER, "タイマーの知らせ", NotificationManager.IMPORTANCE_HIGH))
    }

    private fun postEvent(c: Context, o: JSONObject) {
        channels(c)
        val id = o.optString("id")
        val note = Notification.Builder(c, CH_EVENT)
            .setSmallIcon(android.R.drawable.ic_menu_my_calendar)
            .setCategory(Notification.CATEGORY_EVENT)
            .setContentTitle(o.optString("title"))
            .setContentText(o.optString("body"))
            .setAutoCancel(true)
            .setContentIntent(TimerWidget.open(c, "plan", 6))
            .build()
        c.getSystemService(NotificationManager::class.java).notify("event", id.hashCode(), note)
    }

    private fun timerNote(c: Context, title: String, text: String) = Notification.Builder(c, CH_TIMER)
        .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        .setCategory(Notification.CATEGORY_ALARM)
        .setContentTitle(title)
        .setContentText(text)
        .setAutoCancel(true)
        .setContentIntent(TimerWidget.open(c, "show", 7))
        .addAction(Notification.Action.Builder(null, "■ 止める", TimerNotice.buttonIntent(c, TimerNotice.ACTION_STOP)).build())
        .build()

    private fun postPhase(c: Context, ph: Phase) {
        channels(c)
        val brk = ph.phase == "break"
        val min = (ph.end - ph.start) / 60_000L
        c.getSystemService(NotificationManager::class.java).notify(ID_PHASE,
            timerNote(c, if (brk) "休憩に入ります" else "集中を再開します", "${if (brk) "休憩" else "集中"} ${min}分"))
    }

    private fun postForgot(c: Context, st: JSONObject) {
        channels(c)
        val run = st.optLong("runStart").takeIf { it > 0 } ?: st.optLong("start")
        val hours = (System.currentTimeMillis() - run) / 3600_000L
        c.getSystemService(NotificationManager::class.java).notify(ID_FORGOT,
            timerNote(c, "タイマーを止め忘れていませんか", "${hours}時間ほど計っています。開くと、止めた時刻を直せます"))
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Alarms.fire(context)
}
