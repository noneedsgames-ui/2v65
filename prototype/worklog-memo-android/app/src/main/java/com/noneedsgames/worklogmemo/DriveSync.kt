package com.noneedsgames.worklogmemo

import android.app.Activity
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import com.google.android.gms.tasks.Tasks
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

/**
 * ドライブで同期:利用者の Google ドライブの、このアプリ専用の隠しフォルダ(appDataFolder)に
 * worklog-sync.json を一つ置いて読み書きする。中身の突き合わせは画面の側(index.html)が行う。
 * ブラウザ版と同じ Google Cloud プロジェクトの OAuth クライアント(パッケージ名と署名の SHA-1 で登録)を使うので、同じフォルダを見る
 */
object DriveSync {
    private const val SCOPE = "https://www.googleapis.com/auth/drive.appdata"
    private const val FILE = "worklog-sync.json"
    private const val API = "https://www.googleapis.com/drive/v3"
    private const val UP = "https://www.googleapis.com/upload/drive/v3/files"

    class HttpError(val code: Int) : Exception("HTTP $code")

    fun request(): AuthorizationRequest = AuthorizationRequest.builder().setRequestedScopes(listOf(Scope(SCOPE))).build()

    /** 画面を出さずに鍵(アクセストークン)を得る。まだ許可されていなければ null。裏のスレッドで呼ぶ */
    fun silentToken(a: Activity): String? {
        val r = Tasks.await(Identity.getAuthorizationClient(a).authorize(request()), 30, TimeUnit.SECONDS)
        return if (r.hasResolution()) null else r.accessToken
    }

    private fun http(method: String, url: String, token: String, body: ByteArray? = null, type: String? = null): String {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.connectTimeout = 20000; c.readTimeout = 60000
            // HttpURLConnection は PATCH を送れないので、Google の API が受け付ける書き方で送る
            if (method == "PATCH") { c.requestMethod = "POST"; c.setRequestProperty("X-HTTP-Method-Override", "PATCH") } else c.requestMethod = method
            c.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) { c.doOutput = true; c.setRequestProperty("Content-Type", type); c.outputStream.use { it.write(body) } }
            val code = c.responseCode
            if (code !in 200..299) throw HttpError(code)
            return c.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }
        } finally { c.disconnect() }
    }

    /** 同期のファイル {id, text}。まだなければ null */
    fun get(token: String): JSONObject? {
        val q = URLEncoder.encode("name='$FILE'", "UTF-8")
        val files = JSONObject(http("GET", "$API/files?spaces=appDataFolder&q=$q&fields=files(id)&pageSize=10", token)).optJSONArray("files")
        if (files == null || files.length() == 0) return null
        val id = files.getJSONObject(0).getString("id")
        return JSONObject().put("id", id).put("text", http("GET", "$API/files/${URLEncoder.encode(id, "UTF-8")}?alt=media", token))
    }

    /** 書く。id が空なら作る。書いたファイルの id を返す */
    fun put(token: String, id: String, text: String): String {
        if (id.isNotEmpty()) {
            http("PATCH", "$UP/${URLEncoder.encode(id, "UTF-8")}?uploadType=media", token, text.toByteArray(), "application/json")
            return id
        }
        val b = "wm" + System.currentTimeMillis()
        val head = JSONObject().put("name", FILE).put("parents", JSONArray().put("appDataFolder")).put("mimeType", "application/json")
        val body = "--$b\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$head\r\n--$b\r\nContent-Type: application/json\r\n\r\n$text\r\n--$b--"
        return JSONObject(http("POST", "$UP?uploadType=multipart&fields=id", token, body.toByteArray(), "multipart/related; boundary=$b")).getString("id")
    }

    fun email(token: String): String =
        JSONObject(http("GET", "$API/about?fields=user(emailAddress)", token)).optJSONObject("user")?.optString("emailAddress") ?: ""

    /** 同期をやめるとき、このアプリへの許可を取り消す */
    fun revoke(token: String) {
        try { http("POST", "https://oauth2.googleapis.com/revoke?token=" + URLEncoder.encode(token, "UTF-8"), token, ByteArray(0), "application/x-www-form-urlencoded") } catch (_: Exception) {}
    }
}
