# このリポジトリで作業する Claude へ(引き継ぎ)

このリポジトリには二つのものが入っている。

- **Gathering Frontier**(ルートの `project.godot`・`scenes/`・`scripts/`・`assets/`):Godot 4 の横スクロール素材採集ゲーム。詳しくはルートの `README.md`。
- **作業記録メモ帳**(`prototype/`):いま主に作っているアプリ。以下はこのアプリの引き継ぎ。

作業するブランチは `ccr-a6f51c3a-jl9xh6`(main ではない)。

## 利用者について

- 返答は、長編小説のように硬派な日本語で書く。ある程度は補って説明する。
- パソコンは **Windows**。スマホは Android。リポジトリは GitHub Desktop でクローンし、Android Studio で `prototype/worklog-memo-android` を開いてビルドしている(Gradle JVM は 21。Git for Windows は入っていないかもしれない)。
- 画面の写真を見せて質問してくることが多い。手順は、押すボタンの名前をそのまま書いて案内する。
- 機能の要望は細かく続けて来る。直したら、何を変えたかを短く報告する。

## 作業記録メモ帳の作り

```
prototype/worklog-memo/index.html      アプリの本体(HTML・CSS・JS を一つのファイルに)
prototype/worklog-memo/README.md       機能の一覧(機能を足したら、ここも更新する)
prototype/worklog-memo/mimoza.png      マスコット「ミモザ」(index.html には base64 で埋め込み済み)
prototype/worklog-memo-android/        Android アプリ(Kotlin)。画面は index.html をそのまま WebView で出す
.github/workflows/worklog-memo-apk.yml APK・AAB を作る GitHub Actions(手で「Run workflow」したときだけ動く)
```

### index.html の中の区切り

コメントの `/* ===` で区切ってある。主な所:保存層(Store・LS)→ データモデル(loadAll)→ 作業時間の自動記録(Work)→ 画面切り替え(show)→ メモ(入れ子のアウトライン)→ ボード(カード・丸=ファイル・矢印、複数のボード、タグのベン図)→ 左のツリー → つながり → 記録(積み上げグラフ)→ タイマー → 予定 → 設定 → 起動(boot)。

### データ

- 端末内の localStorage(キーは `wm:` で始まる)を正とし、claude.ai の試作ページで開いたときだけ、claude.ai の個人用ストアにも同期する。
- 文書:`meta`(設定・予定・作業の種類・ボードの一覧 `meta.boards`)、`file-<id>`(メモ 1 件)、`board`(メインのボード)、`board-<id>`(ほかのボード)、`log-YYYY-MM`(作業区間・タイマーの記録)。
- **ブラウザ版とアプリ版のデータは別々**。アプリは同じ鍵で上書きして入れる限り、更新してもデータは残る。

### Android 版

- `MainActivity.kt`:WebView で `file:///android_asset/index.html` を開く。端末の機能は JS から `Android.*` で呼ぶ(使用時間・集中ブロック・ウィジェットへの状態 `timerState`)。
- `TimerNotice.kt`:ロック画面の通知。ボタンはアプリを開かず、押した時刻を貯める(`Android.takeTimerEvents`)。画面側の `takeNoticeEvents` がそれを記録へ移す。
- `BlockService.kt`:タイマー中、選んだ妨害アプリを覆う(試験運用、最大 5 分)。
- `TimerWidget.kt`:ホーム画面のウィジェット「作業タイマー」。押すとアプリを開き、`window.onWidget('stopwatch'|'pomodoro'|'stop'|'show')` を呼ぶ。
- ビルドのたびに `../worklog-memo/index.html` を assets に写す(`app/build.gradle.kts` の copyWeb)。なので **リポジトリ全体** が要る。
- debug ビルドは `app/debug.keystore`(試作用の固定鍵)で署名し、`com.noneedsgames.worklogmemo.dev`「作業記録メモ帳(試作)」として入る。
- Windows で動かすとき:`cd prototype\worklog-memo-android` で `.\gradlew.bat installDebug`(スマホを USB デバッグでつないでおく)。ログは `adb logcat`。

## 確かめ方

- 画面の変更は、`index.html` をブラウザで開いて確かめられる。スマホの大きさ(幅 390px 前後)で見る。
- `#start=stopwatch`・`#start=pomodoro`・`#stop` を付けて開くと、ウィジェットと同じ動きになる。
- 自動テストはリポジトリに入っていない(これまではクラウドの作業環境で Playwright を使っていた)。

## 守ること

- **鍵を絶対にコミットしない**。Play のアップロード鍵(`upload.jks`・`UPLOAD_KEYSTORE_BASE64.txt`・`UPLOAD_KEYSTORE_PASSWORD.txt`)は利用者が別に持っている。GitHub の Secrets に入れる手順は `prototype/worklog-memo-android/PLAY_RELEASE.md`。
- コミットや画面の文言は日本語。「〜する」で終わる短い要約を一行目に書く。
- 頼まれていないプルリクエストは作らない。push は `ccr-a6f51c3a-jl9xh6` へ。
- 機能を足したり変えたりしたら、`prototype/worklog-memo/README.md` の表も直す。
- アプリ化(Play への公開)はいったん保留中で、いまは HTML 版の中身を磨いている。

## 残っていること・提案中のこと

- **読み込むファイルの中身**:ID などをそのまま画面に入れているので、自分で書き出したファイルだけを読み込む前提。

- **データの書き出し/読み込み**:設定の「データの引っ越し」として実装した。Android の保存・ファイル選択(`MainActivity.kt`)と claude.ai 上の `downloads` は実機で未確認。
- **ウィジェット・ロック画面の通知**:ビルドは通ったが、実機での確認はまだ。
- **Google Play の内部テスト**:Secrets にアップロード鍵がまだ入っていないので、AAB は作られていない。Actions で「Releases に置く」が 403(権限)で失敗するが、APK は実行結果の Artifacts から落とせる(失敗扱いにはしないよう直してある)。
