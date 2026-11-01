plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.noneedsgames.worklogmemo"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.noneedsgames.worklogmemo"
        minSdk = 26 // 要件書:Android 8 以降
        targetSdk = 36 // Google Play の新規アプリの条件(最新の Android を対象にする)
        // GitHub Actions の実行番号を版の番号にする(新しい版を上書きで入れられるように)
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = "0.1.$versionCode"
        resValue("string", "app_name", "作業記録メモ帳")
    }
    buildFeatures { resValues = true }

    // Google Play に出すときのアップロード鍵。鍵そのものはリポジトリに置かず、
    // GitHub の Secrets から一時ファイルに書き出して、場所とパスワードを環境変数で渡す
    val uploadStore = System.getenv("UPLOAD_KEYSTORE_PATH")?.takeIf { it.isNotBlank() && file(it).exists() }
    val uploadPass = System.getenv("UPLOAD_KEYSTORE_PASSWORD") ?: ""

    signingConfigs {
        // 試作用の固定のデバッグ鍵。毎回同じ鍵で署名するので、入れ直さずに上書きで更新でき、データも残る
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (uploadStore != null) create("upload") {
            storeFile = file(uploadStore)
            storePassword = uploadPass
            keyAlias = "upload"
            keyPassword = uploadPass
        }
    }
    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            // 直接入れて試す版は別のアプリとして入る(Play から入れる版と並べて置ける)
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "作業記録メモ帳(試作)")
        }
        getByName("release") {
            // WebView と JavascriptInterface を使うので、名前の縮めは行わない
            isMinifyEnabled = false
            if (uploadStore != null) signingConfig = signingConfigs.getByName("upload")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 画面は Web 試作の index.html をそのまま使う(ビルドのたびに写す)
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/webassets").get().asFile)
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

val copyWeb = tasks.register<Copy>("copyWeb") {
    from(rootDir.resolve("../worklog-memo/index.html"))
    into(layout.buildDirectory.dir("generated/webassets"))
}
tasks.named("preBuild") { dependsOn(copyWeb) }
