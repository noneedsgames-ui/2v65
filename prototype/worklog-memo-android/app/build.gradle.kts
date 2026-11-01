plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.noneedsgames.worklogmemo"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.noneedsgames.worklogmemo"
        minSdk = 26 // 要件書:Android 8 以降
        targetSdk = 34
        // GitHub Actions の実行番号を版の番号にする(新しい版を上書きで入れられるように)
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = "0.1.$versionCode"
    }

    signingConfigs {
        // 試作用の固定のデバッグ鍵。毎回同じ鍵で署名するので、入れ直さずに上書きで更新でき、データも残る
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
    buildTypes {
        getByName("debug") { signingConfig = signingConfigs.getByName("debug") }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    // 画面は Web 試作の index.html をそのまま使う(ビルドのたびに写す)
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/webassets").get().asFile)
}

val copyWeb = tasks.register<Copy>("copyWeb") {
    from(rootDir.resolve("../worklog-memo/index.html"))
    into(layout.buildDirectory.dir("generated/webassets"))
}
tasks.named("preBuild") { dependsOn(copyWeb) }
