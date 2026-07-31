# Gathering Frontier

Godot 4 (GDScript) 製の横スクロール素材採集ゲームです。プレイヤーには、その2倍の背丈を持つサブキャラクター(仲間)が追随します。野原で素材を集め、町で売り買いし、自分の露店で商売ができます。

## 動作環境

- Godot Engine 4.6(`config/features` は `4.6` を宣言。GL Compatibility レンダラーを使用)
- `project.godot` を Godot エディタで開き、`res://scenes/Main.tscn` を実行してください

シーン・スクリプトは `format=3` / `config_version=5` で記述しており、Godot 4.4 以降で導入された
スクリプト UID(`*.gd.uid`)はエディタで初回に開いた時点で自動生成されます。生成された `.uid`
ファイルはバージョン管理に含めてください(`.gitignore` では除外していません)。

アイテムのアイコンは `assets/icons/*.svg` です。Godot がまだ SVG をインポートしていない状態
(エディタで一度も開いていない状態)では画像を読み込めないため、その場合はアイテムごとの色で
塗った四角にフォールバックします。エディタで開けば自動的にインポートされ、絵が表示されます。

## 操作方法

| キー | 動作 |
|---|---|
| A / D または ← / → | 左右移動 |
| Space | ジャンプ |
| E | 調べる・採集する・施設に入る |
| I | 持ち物(インベントリ)を開閉 |
| C | クラフト画面を開閉 |
| 1 - 8 | ホットバーのスロットを選択 |
| Q / R | ホットバーの選択を左右に送る |
| F | 選択中のアイテムを使う(食べる / 装備する) |
| Esc | 開いているメニューを閉じる |

ホットバーの升目は直接クリックでも操作できます。選択済みの升目をもう一度押すと使用します。

## ワールド構成

- **野原(`scenes/Main.tscn`)**: 採集場所。家と店がある。右端の門に触れると町へ移動します
- **町(`scenes/Town.tscn`)**: 大勢の町人が歩き回り、品揃えの違う店が4軒とプレイヤーの露店があります。左端の門から野原へ戻れます

## 主な機能

- **横スクロール操作**: `CharacterBody2D` によるプレイヤー移動・ジャンプ
- **サブキャラクター(仲間)**: プレイヤーの移動履歴を辿って追従する、プレイヤーの2倍の背丈を持つキャラクター(`scripts/Companion.gd`)。ジャンプの軌道もそのまま再現します
- **採集**: 木・岩・茂み・鉄鉱脈・草むらから素材を採集(`scripts/ResourceNode.gd`)。採集後は時間経過で再湧きします
- **インベントリ**: アイテム画像だけを並べた升目表示。升目を選ぶと右側に名前・種類・説明・売買値が出ます(`scripts/ui/InventoryUI.gd`)
- **装備**: 「装備品」タブで道具スロットとアクセサリスロットに装備できます(`scripts/autoload/Equipment.gd`)
  - 斧・ツルハシ: 装備すると採集量が増える。鉄鉱脈の採掘にはツルハシの**装備**が必須
  - 採集かご: どの採集でも取れ高が増える
- **ホットバー**: インベントリ先頭8スロットを画面下に常時表示。数字キーで選んで F で使用します
- **家**: 収納チェストへの出し入れと、ベッドで眠ることによるセーブ(`scripts/House.gd`)。セーブデータは起動時に `scripts/WorldRoot.gd` が自動で読み込みます
- **店**: 町には道具屋・食料品店・建材屋・雑貨屋があり、それぞれ品揃えが違います(`scripts/Shop.gd` の `stock` で指定)
- **露店(出店)**: 町の広場に構えます。開くには**露店キット**が必要です
  - 持ち物を並べて値段を付けると、町人が実際に歩いて来て買っていきます
  - ただし一定確率で代金を払わずに持ち去られます(**万引き**)。売上と被害は露店画面のログに残ります
- **クラフト**: 素材を組み合わせて道具・加工品を作成(`scripts/autoload/RecipeDB.gd`)

## プロジェクト構成

```
project.godot
assets/icons/          アイテムアイコン(SVG)
scenes/
  Main.tscn            野原(起動シーン)
  Town.tscn            町
  Player.tscn / Companion.tscn / TownNPC.tscn
  House.tscn / Shop.tscn / Stall.tscn / SceneDoor.tscn
  Tree.tscn / Rock.tscn / Bush.tscn / IronVein.tscn / FiberPatch.tscn
  ui/                  HUD・ホットバー・升目・各種メニュー
scripts/
  WorldRoot.gd          各ワールドの共通ルート(スポーン配置とセーブ読み込み)
  Player.gd / Companion.gd / TownNPC.gd
  ResourceNode.gd / House.gd / Shop.gd / Stall.gd / SceneDoor.gd
  UIRowFactory.gd       UI行の共通生成ヘルパー
  autoload/             ItemDB, RecipeDB, Inventory, Equipment, GameState, EventBus
  ui/                   各UIパネルのスクリプト
```

キャラクターや建物の見た目はプレースホルダーの図形(Polygon2D)で構成されています。
