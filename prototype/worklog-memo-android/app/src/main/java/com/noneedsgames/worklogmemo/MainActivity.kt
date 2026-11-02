package com.noneedsgames.worklogmemo

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.NotificationManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.LinearLayout
import android.window.OnBackInvokedDispatcher
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import org.json.JSONObject

/** 画面は Web 試作(assets/index.html)をそのまま使い、端末の機能は Android という名前で渡す */
class MainActivity : Activity() {

    private lateinit var web: WebView
    private var pageReady = false
    private var topBar: View? = null
    private var bottomBar: View? = null
    private var rootBar: View? = null
    private var pendingWidget: String? = null // ウィジェットから頼まれた操作(画面の読み込みが済んだら渡す)
    private var pendingSave: String? = null // 書き出す文章(保存先を選び終えたら書く)
    private var pendingPick: ValueCallback<Array<Uri>>? = null // 読み込むファイルの選択を待っている画面側の受け口

    companion object {
        private const val REQ_PICK = 1001
        private const val REQ_SAVE = 1002
        private const val REQ_AUTO = 1003
        @Volatile var inFront = false // 前面で使っている間は、知らせを画面の側に任せる
    }

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
            override fun onPageFinished(view: WebView, url: String) { pageReady = true; flushWidget() }
        }
        // WebView の <input type="file"> は、これがないと何も開かない
        web.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(view: WebView, callback: ValueCallback<Array<Uri>>, params: WebChromeClient.FileChooserParams): Boolean {
                pendingPick?.onReceiveValue(null)
                pendingPick = callback
                val i = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                try { startActivityForResult(i, REQ_PICK) } catch (_: Exception) { pendingPick = null; callback.onReceiveValue(null) }
                return true
            }
        }
        pendingWidget = widgetAction(intent)
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
        val top = View(this)
        val bottom = View(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
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
        topBar = top; bottomBar = bottom; rootBar = root
        paintBars(isNight())
        return root
    }

    private fun isNight() = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    /** バーの帯と、そこに出る時計やアイコンの色を、画面の色に合わせる */
    private fun paintBars(dark: Boolean) {
        topBar?.setBackgroundColor(Color.parseColor(if (dark) "#252523" else "#ECEBE6"))
        bottomBar?.setBackgroundColor(Color.parseColor(if (dark) "#1A1A19" else "#FCFCFB"))
        rootBar?.setBackgroundColor(Color.parseColor(if (dark) "#121211" else "#F4F3EF"))
        web.setBackgroundColor(Color.parseColor(if (dark) "#121211" else "#F4F3EF"))
        if (Build.VERSION.SDK_INT >= 30) {
            val mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (dark) 0 else mask, mask)
        }
    }

    // 端末の色が変わったら、「端末に合わせる」の画面にも伝える(uiMode は作り直さずに受ける)
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        web.evaluateJavascript("window.applyTheme && window.applyTheme()", null)
    }

    /** 戻る:画面の中で閉じるものがあれば閉じる。なければアプリを裏へ下げる */
    private fun handleBack() {
        web.evaluateJavascript("(window.androidBack && window.androidBack()) ? 'y' : 'n'") { r ->
            if (r?.contains("y") != true) moveTaskToBack(true)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingWidget = widgetAction(intent)
        if (pageReady) flushWidget()
    }

    private fun widgetAction(i: Intent?): String? {
        if (i?.action != TimerWidget.ACTION) return null
        val a = i.getStringExtra(TimerWidget.EXTRA)?.takeIf { it in TimerWidget.ACTIONS }
        i.removeExtra(TimerWidget.EXTRA) // 画面を作り直したときに、もう一度始めないように
        return a
    }

    private fun flushWidget() {
        val a = pendingWidget ?: return
        pendingWidget = null
        web.evaluateJavascript("window.onWidget && window.onWidget('$a')", null)
    }

    // 通知の許可が下りたら、すぐ通知を出す
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        TimerNotice.refresh(this)
    }

    override fun onSaveInstanceState(outState: Bundle) { super.onSaveInstanceState(outState); web.saveState(outState) }

    override fun onResume() {
        super.onResume()
        inFront = true
        web.onResume()
        // 設定画面から戻ったときなどに、許可や使用時間を読み直させる
        web.evaluateJavascript("window.onAndroidResume && window.onAndroidResume()", null)
    }

    override fun onPause() { inFront = false; web.onPause(); super.onPause() }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { handleBack() } // Android 12 以前

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri = data?.data?.takeIf { resultCode == RESULT_OK }
        when (requestCode) {
            REQ_PICK -> { pendingPick?.onReceiveValue(uri?.let { arrayOf(it) }); pendingPick = null }
            REQ_SAVE -> {
                val text = pendingSave; pendingSave = null
                if (uri == null || text == null) return // 保存先を選ばずに戻ったときは何も言わない
                val ok = try { writeUri(uri, text); true } catch (_: Exception) { false }
                web.evaluateJavascript("window.onBackupSaved && window.onBackupSaved($ok)", null)
            }
            REQ_AUTO -> {
                if (uri == null) return
                val ok = try { // 次からは尋ねずに書けるよう、保存先の許可を持ち続ける
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    backupPrefs().edit().putString("backupUri", uri.toString()).apply(); true
                } catch (_: Exception) { false }
                web.evaluateJavascript("window.onBackupChosen && window.onBackupChosen($ok)", null)
            }
        }
    }

    private fun backupPrefs() = getSharedPreferences(TimerWidget.PREFS, MODE_PRIVATE)

    /** 保存先へ丸ごと書く。"wt"(切り詰め)を受け付けない保存先には "w" で書く */
    private fun writeUri(uri: Uri, text: String) {
        val out = try { contentResolver.openOutputStream(uri, "wt") } catch (_: Exception) { contentResolver.openOutputStream(uri, "w") }
        out!!.use { it.write(text.toByteArray()) }
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

        /** [start, end) に、指定したアプリ(JSON配列)が前面にあった区間。{pkg: [[始まり, 終わり], …]} */
        @JavascriptInterface fun usageIntervals(start: Double, end: Double, pkgsJson: String): String {
            if (!UsageReader.hasAccess(this@MainActivity)) return "{}"
            val arr = JSONArray(pkgsJson)
            val set = (0 until arr.length()).map { arr.getString(it) }.toSet()
            val m = UsageReader.foregroundIntervals(this@MainActivity, start.toLong(), end.toLong(), set)
            val o = JSONObject()
            for ((k, list) in m) o.put(k, JSONArray().apply { for (iv in list) put(JSONArray().put(iv[0]).put(iv[1])) })
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

        /** タイマーの様子(JSON)を受け取り、ホーム画面のウィジェットに出す */
        @JavascriptInterface fun timerState(json: String) {
            if (!TimerNotice.hasEvents(this@MainActivity)) TimerWidget.saveState(this@MainActivity, json) // 貯まった出来事を渡す前の古い様子では上書きしない
        }

        /** ロック画面の通知で押された「始める・止める」を受け取る。[{a, t}] */
        @JavascriptInterface fun takeTimerEvents(): String = TimerNotice.takeEvents(this@MainActivity)

        @JavascriptInterface fun setBlockApps(pkgsJson: String) = TimerNotice.setBlockApps(this@MainActivity, pkgsJson)

        /** ロック画面の通知を出す・消す */
        @JavascriptInterface fun setTimerNotice(on: Boolean) = TimerNotice.setEnabled(this@MainActivity, on)

        @JavascriptInterface fun isNightMode(): Boolean = isNight()

        @JavascriptInterface fun setBarsDark(dark: Boolean) = runOnUiThread { paintBars(dark) }

        /** 妨害アプリの使用中に、隅へ使用時間を出すか。pkgsJson は対象のアプリ */
        @JavascriptInterface fun setUsageOverlay(on: Boolean, pkgsJson: String) = UsageOverlayService.configure(this@MainActivity, on, pkgsJson)

        /** 予定の知らせを預ける。[{id, at, title, body}] */
        @JavascriptInterface fun setEventAlarms(json: String) = Alarms.setEvents(this@MainActivity, json)

        @JavascriptInterface fun hasNotifyPerm(): Boolean = getSystemService(NotificationManager::class.java).areNotificationsEnabled()

        /** 通知の許可を尋ねる。理由を説明した画面の流れの中から呼ぶ */
        @JavascriptInterface fun requestNotifyPerm() {
            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                runOnUiThread { requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2) }
        }

        @JavascriptInterface fun openNotifySettings() = runOnUiThread {
            try { startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)) } catch (_: Exception) {}
        }

        @JavascriptInterface fun canExactAlarm(): Boolean = Alarms.canExact(this@MainActivity)

        @JavascriptInterface fun openExactSettings() = runOnUiThread {
            if (Build.VERSION.SDK_INT >= 31) try {
                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
            } catch (_: Exception) {}
        }

        /** WebView では文字のコピーが断られることがあるので、端末の機能で写す。大きすぎて写せなければ false */
        @JavascriptInterface fun copyText(text: String): Boolean = try {
            getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("作業記録メモ帳", text)); true
        } catch (_: Exception) { false }

        @JavascriptInterface fun versionName(): String =
            try { packageManager.getPackageInfo(packageName, 0).versionName ?: "" } catch (_: Exception) { "" }

        @JavascriptInterface fun blockRemainingMs(): Double = BlockService.remainingMs().toDouble()

        /** 自動バックアップの保存先を選んでもらう(保存先の画面で Google ドライブも選べる) */
        @JavascriptInterface fun chooseBackupFile(name: String) = runOnUiThread {
            val i = Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType("application/json").putExtra(Intent.EXTRA_TITLE, name)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            try { startActivityForResult(i, REQ_AUTO) } catch (_: Exception) {
                web.evaluateJavascript("window.onBackupChosen && window.onBackupChosen(false)", null)
            }
        }

        /** 自動バックアップの保存先。{name, drive}。なければ空の文字 */
        @JavascriptInterface fun backupTarget(): String {
            val uri = backupPrefs().getString("backupUri", null)?.let { Uri.parse(it) } ?: return ""
            val name = try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null }
            } catch (_: Exception) { null }
            return JSONObject().put("name", name ?: "").put("drive", uri.authority?.contains("com.google.android.apps.docs") == true).toString()
        }

        /** 自動バックアップを書く。結果は onAutoBackupDone で返す(ドライブへの送信は Google ドライブのアプリが行う) */
        @JavascriptInterface fun writeBackup(text: String) {
            val uri = backupPrefs().getString("backupUri", null)?.let { Uri.parse(it) }
            Thread {
                val ok = uri != null && try { writeUri(uri, text); true } catch (_: Exception) { false }
                runOnUiThread { web.evaluateJavascript("window.onAutoBackupDone && window.onAutoBackupDone($ok)", null) }
            }.start()
        }

        /** 自動バックアップをやめる(保存先のファイルは消さない) */
        @JavascriptInterface fun clearBackup() {
            val p = backupPrefs()
            p.getString("backupUri", null)?.let { s ->
                try { contentResolver.releasePersistableUriPermission(Uri.parse(s), Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION) } catch (_: Exception) {}
            }
            p.edit().remove("backupUri").apply()
        }

        /** データの書き出し:保存先を選んでもらい、そこへ文章を書く */
        @JavascriptInterface fun saveTextFile(name: String, text: String) = runOnUiThread {
            pendingSave = text
            val i = Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType("application/json").putExtra(Intent.EXTRA_TITLE, name)
            try { startActivityForResult(i, REQ_SAVE) } catch (_: Exception) {
                pendingSave = null
                web.evaluateJavascript("window.onBackupSaved && window.onBackupSaved(false)", null)
            }
        }
    }

}
