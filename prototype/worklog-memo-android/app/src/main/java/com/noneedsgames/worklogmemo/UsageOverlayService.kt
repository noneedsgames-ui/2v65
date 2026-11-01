package com.noneedsgames.worklogmemo

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONArray
import java.util.Calendar

/**
 * 妨害アプリが前面にある間、画面の隅に、そのアプリの今日の使用時間を秒まで出す。タイマーとは関係なく動く。
 * 触れない小さな表示で、下のアプリの操作は邪魔しない。設定でオンにしたときだけ動く
 */
class UsageOverlayService : Service() {

    companion object {
        private const val CHANNEL = "usage_overlay"
        private const val NOTE_ID = 5
        private const val REFRESH_MS = 30_000L

        private fun prefs(c: Context) = c.getSharedPreferences(TimerWidget.PREFS, Context.MODE_PRIVATE)

        fun configure(c: Context, on: Boolean, pkgsJson: String) {
            prefs(c).edit().putBoolean("usageOv", on).putString("usageOvApps", pkgsJson).apply()
            sync(c)
        }

        /** 設定と許可に合わせて、動かす・止める */
        fun sync(c: Context) {
            val ok = prefs(c).getBoolean("usageOv", false) && packages(c).isNotEmpty() &&
                UsageReader.hasAccess(c) && Settings.canDrawOverlays(c)
            try {
                if (ok) c.startForegroundService(Intent(c, UsageOverlayService::class.java))
                else c.stopService(Intent(c, UsageOverlayService::class.java))
            } catch (_: Exception) {} // 再起動の直後などに断られても、次にアプリを開けば動く
        }

        private fun packages(c: Context): Set<String> = try {
            val a = JSONArray(prefs(c).getString("usageOvApps", null) ?: "[]")
            (0 until a.length()).map { a.getString(it) }.toSet()
        } catch (_: Exception) { emptySet() }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var label: TextView? = null
    private var lastFg: String? = null
    private var shown: String? = null
    private var baseMs = 0L
    private var baseAt = 0L
    private var pkgs: Set<String> = emptySet()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "妨害アプリの使用時間の表示", NotificationManager.IMPORTANCE_MIN))
        val note = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("妨害アプリの使用時間を表示しています")
            .setContentText("アプリの設定で切れます")
            .setOngoing(true)
            .setContentIntent(TimerWidget.open(this, "prefs", 8))
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTE_ID, note)
        pkgs = packages(this)
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    private val tick = object : Runnable {
        override fun run() {
            val on = step()
            handler.postDelayed(this, if (on) 1000 else 5000) // 画面が消えている間は、確かめる回数を減らす
        }
    }

    /** 画面がついていれば true */
    private fun step(): Boolean {
        val screenOn = getSystemService(PowerManager::class.java).isInteractive &&
            !getSystemService(KeyguardManager::class.java).isKeyguardLocked
        if (!screenOn) { hide(); return false }
        val fg = try { UsageReader.currentForeground(this) } catch (_: Exception) { null }
        if (fg != null) lastFg = fg // 出来事のない間は、前面のアプリは変わっていない
        val cur = lastFg?.takeIf { it in pkgs }
        if (cur == null || !Settings.canDrawOverlays(this)) { hide(); return true }
        val now = System.currentTimeMillis()
        if (cur != shown || now - baseAt >= REFRESH_MS) { // ときどき端末の記録から読み直す。あいだは手元で秒を進める
            baseMs = todayMs(cur, now); baseAt = now; shown = cur
        }
        show(baseMs + (now - baseAt))
        return true
    }

    private fun todayMs(pkg: String, now: Long): Long {
        val c = Calendar.getInstance().apply { timeInMillis = now; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        return try {
            UsageReader.foregroundIntervals(this, c.timeInMillis, now, setOf(pkg))[pkg]?.sumOf { it[1] - it[0] } ?: 0L
        } catch (_: Exception) { 0L }
    }

    private fun show(ms: Long) {
        val v = label ?: create() ?: return
        val s = ms / 1000
        v.text = "%d:%02d:%02d".format(s / 3600, s / 60 % 60, s % 60)
    }

    private fun create(): TextView? {
        val d = resources.displayMetrics.density
        val v = TextView(this).apply {
            textSize = 13f
            setTextColor(Color.WHITE)
            setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
            setPadding((8 * d).toInt(), (3 * d).toInt(), (8 * d).toInt(), (3 * d).toInt())
            background = GradientDrawable().apply { cornerRadius = 10 * d; setColor(Color.parseColor("#C8121211")) }
        }
        val bar = resources.getIdentifier("status_bar_height", "dimen", "android").let { if (it > 0) resources.getDimensionPixelSize(it) else 0 }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.END
            x = (8 * d).toInt(); y = bar + (4 * d).toInt()
            alpha = 0.78f // 不透明に近いと、端末が下のアプリへの指の操作を止めてしまう
        }
        return try { getSystemService(WindowManager::class.java).addView(v, lp); label = v; v } catch (_: Exception) { null }
    }

    private fun hide() {
        shown = null
        val v = label ?: return
        try { getSystemService(WindowManager::class.java).removeView(v) } catch (_: Exception) {}
        label = null
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hide()
        super.onDestroy()
    }
}
