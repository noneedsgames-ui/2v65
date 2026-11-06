# このリポジトリで作業する Claude へ(引き継ぎ)

このリポジトリには **開発メモ**(もとの名前は作業記録メモ帳)(`prototype/`)だけが入っている。以下はこのアプリの引き継ぎ。

以前同居していた Godot のゲーム「Gathering Frontier」は、利用者の希望で 2026-11-03 にリポジトリから外した。履歴のコミット `1657f1a` に、ゲームの最後の姿がまるごと残っている(取り戻すなら `git checkout 1657f1a -- scenes scripts assets project.godot icon.svg README.md`)。

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
prototype/worklog-memo/mimoza.png      マスコット「ミモザ」(アプリ版だけ。copyWeb で assets に写し、index.html からは "mimoza.png" で読む。ブラウザ版には出さない)
prototype/worklog-memo-android/        Android アプリ(Kotlin)。画面は index.html をそのまま WebView で出す
.github/workflows/worklog-memo-apk.yml APK・AAB を作る GitHub Actions(手で「Run workflow」したときだけ動く)
```

ブラウザ版は、別の公開リポジトリ `noneedsgames-ui/worklog-memo`(パソコンでは `C:\dev\worklog-memo-web`)に `index.html` を写して、GitHub Pages(https://noneedsgames-ui.github.io/worklog-memo/)で配る。こちらのリポジトリ(`noneedsgames-ui/2v65`)は公開になっているが、利用者はそれでよいとしている。鍵はコミットしない(試作用の `debug.keystore` だけは入っている)。index.html を直したら、写してコミットし、利用者が GitHub Desktop で push する。claude.ai の試作ページ(https://claude.ai/artifact/92TaFhMc1gCyY58VBR1CsZ)も同じ index.html。

### index.html の中の区切り

コメントの `/* ===` で区切ってある。主な所:保存層(Store・LS)→ データモデル(loadAll)→ 作業時間の自動記録(Work)→ 画面切り替え(show)→ メモ(入れ子のアウトライン)→ ボード(カード・丸=ファイル・矢印、複数のボード、タグのベン図)→ 左のツリー → つながり → 記録(積み上げグラフ)→ タイマー → 予定 → 設定 → 起動(boot)。

### データ

- 端末内の localStorage(キーは `wm:` で始まる)を正とし、claude.ai の試作ページで開いたときだけ、claude.ai の個人用ストアにも同期する。
- 文書:`meta`(設定・予定・作業の種類・ボードの一覧 `meta.boards`)、`file-<id>`(メモ 1 件)、`board`(メインのボード)、`board-<id>`(ほかのボード)、`log-YYYY-MM`(作業区間・タイマーの記録)、`money-YYYY-MM`(収支の記録。プロジェクトの分は proj と line を持つ)、`projects`(プロジェクトの予算)、`plans`(長期計画)、`trash-<id>`(ゴミ箱)。収支と長期計画の画面は、下のタブを増やさず「予定」のページの中に置く。
- **ブラウザ版とアプリ版のデータは別々**。アプリは同じ鍵で上書きして入れる限り、更新してもデータは残る。

### Android 版

- `MainActivity.kt`:WebView で `file:///android_asset/index.html` を開く。端末の機能は JS から `Android.*` で呼ぶ(使用時間・集中ブロック・ウィジェットへの状態 `timerState`)。
- `TimerNotice.kt`:ロック画面の通知。ボタンはアプリを開かず、押した時刻を貯める(`Android.takeTimerEvents`)。画面側の `takeNoticeEvents` がそれを記録へ移す。
- `Alarms.kt`:閉じていても届く知らせ(予定・ポモドーロの区切り・止め忘れ)。予定は画面から `Android.setEventAlarms` で受け取り、タイマーの分は `timerState` の様子から求める。
- `UsageOverlayService.kt`:妨害アプリの使用中に、今日の使用時間を隅へ出す(設定でオンのときだけ常に動く)。
- `BlockService.kt`:タイマー中、選んだ妨害アプリを覆う(試験運用、最大 5 分)。
- `TimerWidget.kt`:ホーム画面のウィジェット「作業タイマー」。押すとアプリを開き、`window.onWidget('stopwatch'|'pomodoro'|'stop'|'show')` を呼ぶ。
- ビルドのたびに `../worklog-memo/index.html` を assets に写す(`app/build.gradle.kts` の copyWeb)。なので **リポジトリ全体** が要る。
- debug ビルドは `app/debug.keystore`(試作用の固定鍵)で署名し、`com.noneedsgames.worklogmemo.dev`「作業記録メモ帳(試作)」として入る。
- Windows で動かすとき:`cd prototype\worklog-memo-android` で `.\gradlew.bat installDebug`(スマホを USB デバッグでつないでおく)。ログは `adb logcat`。

## 確かめ方

- 画面の変更は、`index.html` をブラウザで開いて確かめられる。スマホの大きさ(幅 390px 前後)で見る。
- `#start=stopwatch`・`#start=pomodoro`・`#stop` を付けて開くと、ウィジェットと同じ動きになる。
- 自動テストはリポジトリに入っていない(これまではクラウドの作業環境で Playwright を使っていた)。
- 実機は、debug ビルドなら `adb forward tcp:9333 localabstract:webview_devtools_remote_<pid>` で WebView に Chrome DevTools Protocol でつながり、画面を叩かずに JavaScript を動かして確かめられる。Android の窓口を模すなら `<head>` の先頭で `window.Android` を差し替えた HTML を iframe の srcdoc で開く。
- パソコンの Gradle は JDK 21(`~/.jdks/jbr-21.0.11`)で動かす。Android Studio 同梱の Java は新しすぎて動かない。

## 守ること

- **利用者のスマホを座標で叩かない**。通知の並びは変わるので、別のアプリを開いてしまったことがある。押すなら直前に `uiautomator dump` で文字から位置を求め、それでも画面の操作は頼まれたときだけにする。ウイルス対策アプリなどの警告には触れず、利用者に任せる。
- **鍵を絶対にコミットしない**。Play のアップロード鍵(`upload.jks`・`UPLOAD_KEYSTORE_BASE64.txt`・`UPLOAD_KEYSTORE_PASSWORD.txt`)は利用者が別に持っている。GitHub の Secrets に入れる手順は `prototype/worklog-memo-android/PLAY_RELEASE.md`。
- コミットや画面の文言は日本語。「〜する」で終わる短い要約を一行目に書く。
- 頼まれていないプルリクエストは作らない。push は `ccr-a6f51c3a-jl9xh6` へ。
- 機能を足したり変えたりしたら、`prototype/worklog-memo/README.md` の表も直す。
- アプリ化(Play への公開):2026-11-05 に利用者が「そろそろアプリにする」と決めた。まず Run workflow で `-play.aab` ができるかを確かめ、Play Console の内部テストへ上げる(手順は PLAY_RELEASE.md)。

## 残っていること・提案中のこと

- **文言の手直し**:利用者が Claude Docs の「計画メモ 文言の手直し一覧」(https://claude.ai/artifact/7Nu3vhopESc53GzgNEezja)の「直した文」の欄に書いて返す。返ってきたら、空でない行だけ index.html・app_name・公開ページ(README・privacy.html)へ入れる。アプリの名前は 2026-11-05 に利用者が「開発メモ」に決め、画面・app_name・公開ページ(README・privacy.html)をそろえた(パッケージ名とフォルダ名 worklog-memo はそのまま)。

- **ブラウザ版とアプリ版のドライブ同期(作った。2026-11-02 に利用者の GitHub Pages のブラウザと実機の試作版で、本物の Google にログインして同期できた)**:index.html の「ドライブで同期」(Sync・WebDrive・NativeDrive)と `DriveSync.kt`。偽のドライブを挟んだ二台の模擬では、合わせる・消す・作業の記録・書き直し・落ち着く(余計に書かない)を確かめた。Google Cloud のプロジェクトは利用者が作り、ウェブのクライアント ID は `GOOGLE_WEB_CLIENT_ID` に入れた(承認済みの生成元は GitHub Pages だけなので、localhost ではログインできない)。play-services-auth を足したので `android.useAndroidX=true`。パソコンの Gradle は、新しい部品を落とすとき `-Djavax.net.ssl.trustStoreType=Windows-ROOT` が要る(DRIVE_SYNC.md の末尾)。Play のデータ セーフティの申告(ネットワーク・ドライブ)も直す必要がある。以下はもとの設計:Google ドライブの appDataFolder(scope `drive.appdata`)に `worklog-sync.json` を一つ置く。同じ Google Cloud プロジェクトに Web 用(承認済みの生成元 `https://noneedsgames-ui.github.io`)と Android 用(パッケージ名と SHA-1、debug は `.dev`)の OAuth クライアントを作れば、隠しフォルダを共有できる。
  - 中身:書き出しと同じ形の docs と、消した文書の記録 tomb。
  - 突き合わせ:この端末で初めての同期は planImport で両方を残し、以後は文書ごとに `_ts` の新しい方を採る。`log-` は mergeLog で合わせる。消した記録の時刻が文書の `_ts` 以上なら消す。
  - 同期の時機:Store.schedule・remove で印を付け、60 秒おき・開いたとき・裏へ回ったときに同期する。
  - ブラウザ版:Google Identity Services のトークン(1 時間)を使う。切れたら押してログインし直す。
  - アプリ版:play-services-auth の AuthorizationClient で鍵を取り、Kotlin の HttpURLConnection で読み書きする(PATCH は X-HTTP-Method-Override で送る)。結果は `window.onDrive(n, ok, 文字)` で画面に返す。
  - 合わせて直すもの:INTERNET 権限、プライバシーポリシーの「ネットワークに接続せず」、Play のデータ セーフティ。すべて消すときは同期も外す。claude.ai 上では出さない。

- **画面の編集**:編集モードと自分で作る項目を実装した(中身はメモ)。タイマーやグラフなどの部品をメモの中に置く案は、まだ作っていない。

- **読み込むファイルの中身**:ID などをそのまま画面に入れているので、自分で書き出したファイルだけを読み込む前提。

- **データの書き出し/読み込み**:設定の「データの引っ越し」として実装した。Android の保存・ファイル選択(`MainActivity.kt`)と claude.ai 上の `downloads` は実機で未確認。
- **実機で未確認**:Google ドライブのファイルからの読み込み、翌日以降の自動の上書き、書き出しの保存先の選択、再起動のあとの通知、新しい画面を指で触った使い心地。ロック画面の通知、閉じているときの知らせ、妨害アプリの使用時間の隅の表示は、利用者の実機で確認済み。
- **Norton 360**:直接入れた試作版を入れるたびに「疑わしいアプリ」と出る。Play の版でどうなるかは未確認。
- **Google Play の内部テスト**:2026-11-03 に Play Console の本人確認が済み、利用者が `2v65` の Secrets にアップロード鍵を入れ、同日の Run workflow(#8)で `worklog-memo-8-play.aab` ができた(Releases にも置かれる)。同日、利用者が Play Console でアプリ「開発メモ」(com.noneedsgames.worklogmemo)を作り、#8 の AAB を内部テストとしてリリースした。難読化はしていない(isMinifyEnabled = false。JS から Android.* を名前で呼ぶため)。Actions で「Releases に置く」が 403(権限)で失敗するが、APK は実行結果の Artifacts から落とせる(失敗扱いにはしないよう直してある)。
