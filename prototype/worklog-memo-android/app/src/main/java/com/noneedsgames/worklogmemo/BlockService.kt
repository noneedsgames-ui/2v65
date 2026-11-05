package com.noneedsgames.worklogmemo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 集中タイマー中、指定したアプリが前面に出たら、このアプリの画面で上を覆って使えなくする。
 * 試験運用のため、いちどに使えなくするのは最大5分まで。時間が来たら自分で止まる。
 */
class BlockService : Service() {

    companion object {
        const val MAX_MS = 5 * 60_000L
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
        const val EXTRA_PACKAGES = "packages"
        const val EXTRA_MINUTES = "minutes"
        private const val CHANNEL = "focus_block"
        private const val NOTE_ID = 1

        @Volatile var until = 0L
        @Volatile var blocked: Set<String> = emptySet()
        @Volatile var labels: Map<String, String> = emptyMap()
        fun remainingMs(): Long = maxOf(0L, until - System.currentTimeMillis())

        fun start(ctx: Context, packages: List<String>, minutes: Int) {
            val i = Intent(ctx, BlockService::class.java).setAction(ACTION_START)
                .putExtra(EXTRA_PACKAGES, packages.toTypedArray())
                .putExtra(EXTRA_MINUTES, minutes)
            ctx.startForegroundService(i)
        }

        fun stop(ctx: Context) {
            until = 0L
            ctx.stopService(Intent(ctx, BlockService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var overlay: View? = null
    private var overlayText: TextView? = null
    private var lastFg: String? = null
    private var tickCount = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { until = 0L; stopSelf(); return START_NOT_STICKY }
        val pkgs = intent?.getStringArrayExtra(EXTRA_PACKAGES)?.toSet() ?: emptySet()
        val minutes = intent?.getIntExtra(EXTRA_MINUTES, 5) ?: 5
        blocked = pkgs
        labels = pkgs.associateWith { p ->
            try { packageManager.getApplicationLabel(packageManager.getApplicationInfo(p, 0)).toString() } catch (_: Exception) { p }
        }
        until = System.currentTimeMillis() + minOf(minutes * 60_000L, MAX_MS)
        startInForeground()
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_NOT_STICKY
    }

    private fun startInForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "集中ブロック", NotificationManager.IMPORTANCE_LOW))
        val note = buildNote()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            startForeground(NOTE_ID, note, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTE_ID, note)
    }

    private fun buildNote(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, BlockService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val left = remainingMs() / 1000
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("集中ブロック中(試験・最大5分)")
            .setContentText("あと ${left / 60}:${"%02d".format(left % 60)} ・ ${labels.values.joinToString("・")}")
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "やめる", stop).build())
            .build()
    }

    private val tick = object : Runnable {
        override fun run() {
            if (remainingMs() <= 0L) { stopSelf(); return }
            val fg = try { UsageReader.currentForeground(this@BlockService) } catch (_: Exception) { null }
            if (fg != null) lastFg = fg
            val show = lastFg != null && lastFg in blocked
            if (show) showOverlay() else hideOverlay()
            overlayText?.text = remainText()
            if (++tickCount % 5 == 0) getSystemService(NotificationManager::class.java).notify(NOTE_ID, buildNote())
            handler.postDelayed(this, 600)
        }
    }

    private fun remainText(): String {
        val left = remainingMs() / 1000
        return "集中ブロックが終わるまで あと ${left / 60}:${"%02d".format(left % 60)}"
    }

    private fun showOverlay() {
        if (overlay != null || !Settings.canDrawOverlays(this)) return
        val wm = getSystemService(WindowManager::class.java)
        val d = resources.displayMetrics.density
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2121211"))
            setPadding((28 * d).toInt(), 0, (28 * d).toInt(), 0)
            isClickable = true // 下のアプリには触れさせない
        }
        fun text(s: String, size: Float, bold: Boolean = false, color: String = "#F0EFEC") = TextView(this).apply {
            text = s; textSize = size; setTextColor(Color.parseColor(color)); gravity = Gravity.CENTER
            if (bold) setTypeface(typeface, Typeface.BOLD)
            setPadding(0, (6 * d).toInt(), 0, (6 * d).toInt())
        }
        box.addView(text("集中中です", 26f, true))
        box.addView(text("${labels[lastFg] ?: "このアプリ"} は、集中タイマーのあいだ使えません。", 16f, color = "#C3C2B7"))
        overlayText = text(remainText(), 15f, color = "#8F8D86").also { box.addView(it) }
        fun button(label: String, primary: Boolean, onClick: () -> Unit) = Button(this).apply {
            text = label; textSize = 16f; isAllCaps = false
            setTextColor(Color.parseColor(if (primary) "#FFFFFF" else "#F0EFEC"))
            background = GradientDrawable().apply { cornerRadius = 14 * d; setColor(Color.parseColor(if (primary) "#3987E5" else "#3A3936")) }
            setOnClickListener { onClick() }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (52 * d).toInt()).apply { topMargin = (14 * d).toInt() }
        }
        box.addView(button("開発メモに戻る", true) {
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
            lastFg = packageName; hideOverlay()
        })
        box.addView(button("ホーム画面へ", false) {
            startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            lastFg = null; hideOverlay()
        })
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT)
        try { wm.addView(box, lp); overlay = box } catch (_: Exception) { overlay = null }
    }

    private fun hideOverlay() {
        val v = overlay ?: return
        try { getSystemService(WindowManager::class.java).removeView(v) } catch (_: Exception) {}
        overlay = null; overlayText = null
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hideOverlay()
        until = 0L
        super.onDestroy()
    }
}
