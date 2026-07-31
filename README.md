# Gathering Frontier

Godot 4 (GDScript) 製の横スクロール素材採集ゲームです。プレイヤーには、その2倍の背丈を持つサブキャラクター(仲間)が追随します。家・店・出店(露店)・クラフトなどのシステムを備えています。

## 動作環境

- Godot Engine 4.3 以降を推奨(GL Compatibility レンダラーを使用)
- `project.godot` を Godot エディタで開き、`res://scenes/Main.tscn` を実行してください

## 操作方法

| キー | 動作 |
|---|---|
| A / D または ← / → | 左右移動 |
| Space | ジャンプ |
| E | 調べる・採集する・施設に入る |
| I | 持ち物(インベントリ)を開閉 |
| C | クラフト画面を開閉 |
| Esc | 開いているメニューを閉じる |

## 主な機能

- **横スクロール操作**: `CharacterBody2D` によるプレイヤー移動・ジャンプ
- **サブキャラクター(仲間)**: プレイヤーの移動履歴を辿って追従する、プレイヤーの2倍の背丈を持つキャラクター(`scripts/Companion.gd`)。ジャンプの軌道もそのまま再現します
- **採集**: 木・岩・茂み・鉄鉱脈・草むらから素材を採集(`scripts/ResourceNode.gd`)。採集後は時間経過で再湧きします。鉄鉱脈はツルハシが必要です
- **家**: 収納チェストへの出し入れと、ベッドで眠ることによるセーブ/ロード(`scripts/House.gd`, `scripts/autoload/GameState.gd`)
- **店**: NPCの店でアイテムの購入・売却(`scripts/Shop.gd`)
- **出店(露店)**: 持ち物を露店に並べて価格を設定すると、時間経過で客が自動的に購入してくれます(`scripts/Stall.gd`)
- **クラフト**: 素材を組み合わせて道具・加工品を作成(`scripts/autoload/RecipeDB.gd`)
- **インベントリ**: 20スロットの所持品管理とゴールド所持(`scripts/autoload/Inventory.gd`)

## プロジェクト構成

```
project.godot
scenes/
  Main.tscn            メインのワールドシーン
  Player.tscn / Companion.tscn
  House.tscn / Shop.tscn / Stall.tscn
  Tree.tscn / Rock.tscn / Bush.tscn / IronVein.tscn / FiberPatch.tscn
  ui/                   各種メニューUI(インベントリ・家・店・露店・クラフト・HUD)
scripts/
  Player.gd / Companion.gd / ResourceNode.gd
  House.gd / Shop.gd / Stall.gd
  UIRowFactory.gd       UI行の共通生成ヘルパー
  autoload/             グローバルシングルトン(ItemDB, RecipeDB, Inventory, GameState, EventBus)
  ui/                   各UIパネルのスクリプト
```

見た目はすべてプレースホルダーの図形(Polygon2D)で構成されています。実際の素材(スプライト等)を用意すれば差し替え可能です。
