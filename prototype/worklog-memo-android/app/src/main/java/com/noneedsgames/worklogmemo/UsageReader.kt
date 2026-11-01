package com.noneedsgames.worklogmemo

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

/** ほかのアプリの使用時間を、端末の使用状況データ(UsageStatsManager)から読む */
object UsageReader {

    fun hasAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        else
            @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isForeground(type: Int) =
        type == UsageEvents.Event.MOVE_TO_FOREGROUND // = ACTIVITY_RESUMED

    private fun isBackground(type: Int) =
        type == UsageEvents.Event.MOVE_TO_BACKGROUND // = ACTIVITY_PAUSED

    private fun isScreenOff(type: Int) =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE || type == UsageEvents.Event.KEYGUARD_SHOWN)

    /**
     * [start, end) のあいだに、各アプリが前面にあった区間(ミリ秒の始まりと終わり)。
     * 画面が消えた・鍵がかかったときは、その時点で区切る。
     */
    fun foregroundIntervals(ctx: Context, start: Long, end: Long, packages: Set<String>?): Map<String, List<LongArray>> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val result = HashMap<String, MutableList<LongArray>>()
        // 区間の前から前面に出ていたアプリも拾えるよう、少し前から読む
        val events = usm.queryEvents(start - 3 * 3600_000L, end)
        val e = UsageEvents.Event()
        var cur: String? = null
        var since = 0L
        fun close(at: Long) {
            val p = cur ?: return
            val s = maxOf(since, start)
            val t = minOf(at, end)
            if (t > s && (packages == null || p in packages)) result.getOrPut(p) { mutableListOf() }.add(longArrayOf(s, t))
            cur = null
        }
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val t = e.timeStamp
            when {
                isForeground(e.eventType) -> {
                    if (cur != e.packageName) { close(t); cur = e.packageName; since = t }
                }
                isBackground(e.eventType) -> if (cur == e.packageName) close(t)
                isScreenOff(e.eventType) -> close(t)
            }
        }
        close(minOf(System.currentTimeMillis(), end))
        return result
    }

    /** いま前面にあるアプリ(直近の出来事から判断する) */
    fun currentForeground(ctx: Context, lookbackMs: Long = 60_000L): String? {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - lookbackMs, now)
        val e = UsageEvents.Event()
        var cur: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when {
                isForeground(e.eventType) -> cur = e.packageName
                isBackground(e.eventType) -> if (cur == e.packageName) cur = null
                isScreenOff(e.eventType) -> cur = null
            }
        }
        return cur
    }
}
