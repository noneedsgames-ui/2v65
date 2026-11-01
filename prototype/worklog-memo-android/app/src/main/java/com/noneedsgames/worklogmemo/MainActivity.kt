package com.noneedsgames.worklogmemo

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import org.json.JSONObject

/** 画面は Web 試作(assets/index.html)をそのまま使い、端末の機能は Android という名前で渡す */
class MainActivity : Activity() {

    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        web = WebView(this)
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true // メモや記録は端末内(localStorage)に保存する
            allowFileAccess = true
            mediaPlaybackRequiresUserGesture = false
            textZoom = 100
        }
        web.addJavascriptInterface(Bridge(), "Android")
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val u = request.url
                if (u.scheme == "file") return false
                try { startActivity(Intent(Intent.ACTION_VIEW, u)) } catch (_: Exception) {}
                return true
            }
        }
        setContentView(web)
        if (savedInstanceState == null || web.restoreState(savedInstanceState) == null)
            web.loadUrl("file:///android_asset/index.html")
    }

    override fun onSaveInstanceState(outState: Bundle) { super.onSaveInstanceState(outState); web.saveState(outState) }

    override fun onResume() {
        super.onResume()
        web.onResume()
        // 設定画面から戻ったときなどに、許可や使用時間を読み直させる
        web.evaluateJavascript("window.onAndroidResume && window.onAndroidResume()", null)
    }

    override fun onPause() { web.onPause(); super.onPause() }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        web.evaluateJavascript("(window.androidBack && window.androidBack()) ? 'y' : 'n'") { r ->
            if (r?.contains("y") != true) {
                @Suppress("DEPRECATION") super.onBackPressed()
            }
        }
    }

    inner class Bridge {
        @JavascriptInterface fun isNative(): Boolean = true

        @JavascriptInterface fun hasUsageAccess(): Boolean = UsageReader.hasAccess(this@MainActivity)

        @JavascriptInterface fun canOverlay(): Boolean = Settings.canDrawOverlays(this@MainActivity)

        @JavascriptInterface fun openUsageAccessSettings() = runOnUiThread {
            try { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)) } catch (_: Exception) {}
        }

        @JavascriptInterface fun openOverlaySettings() = runOnUiThread {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
            } catch (_: Exception) { startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)) }
        }

        /** 端末に入っているアプリ(ホーム画面に出るもの)。[{pkg, label}] */
        @JavascriptInterface fun listApps(): String {
            val pm = packageManager
            val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val list = pm.queryIntentActivities(i, 0)
                .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
                .filter { it.first != packageName }
                .distinctBy { it.first }
                .sortedBy { it.second }
            val a = JSONArray()
            for ((p, l) in list) a.put(JSONObject().put("pkg", p).put("label", l))
            return a.toString()
        }

        /** [start, end) に、指定したアプリ(JSON配列)が前面にあった時間。{pkg: ミリ秒} */
        @JavascriptInterface fun usage(start: Double, end: Double, pkgsJson: String): String {
            if (!UsageReader.hasAccess(this@MainActivity)) return "{}"
            val arr = JSONArray(pkgsJson)
            val set = (0 until arr.length()).map { arr.getString(it) }.toSet()
            val m = UsageReader.foregroundMs(this@MainActivity, start.toLong(), end.toLong(), set)
            val o = JSONObject(); for ((k, v) in m) o.put(k, v)
            return o.toString()
        }

        /** 集中ブロックを始める(試験運用・最大5分)。許可が足りなければ false */
        @JavascriptInterface fun startBlock(pkgsJson: String, minutes: Int): Boolean {
            if (!UsageReader.hasAccess(this@MainActivity) || !Settings.canDrawOverlays(this@MainActivity)) return false
            val arr = JSONArray(pkgsJson)
            val pkgs = (0 until arr.length()).map { arr.getString(it) }
            if (pkgs.isEmpty()) return false
            runOnUiThread {
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                BlockService.start(this@MainActivity, pkgs, minutes.coerceIn(1, 5))
            }
            return true
        }

        @JavascriptInterface fun stopBlock() = runOnUiThread { BlockService.stop(this@MainActivity) }

        @JavascriptInterface fun blockRemainingMs(): Double = BlockService.remainingMs().toDouble()
    }
}
