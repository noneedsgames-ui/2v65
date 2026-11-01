package com.noneedsgames.worklogmemo

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.widget.LinearLayout
import android.window.OnBackInvokedDispatcher
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
        setContentView(withInsets(web))
        // 戻るボタン(Android 13 以降は「予測型の戻る」の仕組みで受ける)
        if (Build.VERSION.SDK_INT >= 33)
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { handleBack() }
        if (savedInstanceState == null || web.restoreState(savedInstanceState) == null)
            web.loadUrl("file:///android_asset/index.html")
    }

    /**
     * 画面を端まで使う(Android 15 以降は必ずそうなる)ので、ステータスバー・ナビゲーションバー・キーボードの分だけ
     * 上下に余白を置き、画面がバーやキーボードに隠れないようにする
     */
    private fun withInsets(content: View): View {
        if (Build.VERSION.SDK_INT < 30) return content // 古い Android は、これまでどおりバーの内側に描かれる
        window.setDecorFitsSystemWindows(false)
        val night = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val top = View(this).apply { setBackgroundColor(Color.parseColor(if (night) "#252523" else "#ECEBE6")) }
        val bottom = View(this).apply { setBackgroundColor(Color.parseColor(if (night) "#1A1A19" else "#FCFCFB")) }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(if (night) "#121211" else "#F4F3EF"))
            addView(top, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0))
            addView(content, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
            addView(bottom, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0))
        }
        root.setOnApplyWindowInsetsListener { v, insets ->
            val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            val ime = insets.getInsets(WindowInsets.Type.ime())
            v.setPadding(bars.left, 0, bars.right, 0)
            top.layoutParams = (top.layoutParams as LinearLayout.LayoutParams).apply { height = bars.top }
            bottom.layoutParams = (bottom.layoutParams as LinearLayout.LayoutParams).apply { height = maxOf(bars.bottom, ime.bottom) }
            top.requestLayout(); bottom.requestLayout()
            WindowInsets.CONSUMED
        }
        return root
    }

    /** 戻る:画面の中で閉じるものがあれば閉じる。なければアプリを裏へ下げる */
    private fun handleBack() {
        web.evaluateJavascript("(window.androidBack && window.androidBack()) ? 'y' : 'n'") { r ->
            if (r?.contains("y") != true) moveTaskToBack(true)
        }
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
    override fun onBackPressed() { handleBack() } // Android 12 以前

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
