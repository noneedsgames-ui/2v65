extends Node
## グローバルイベント中継用のシングルトン。
## UI とワールド間の疎結合な通知に使う。

signal interact_prompt_show(text: String)
signal interact_prompt_hide()
## 調べられるものの状態が変わったとき(素材の再湧きなど)に、
## プレイヤーがその場から動かなくても操作案内を出し直すための合図。
signal request_prompt_refresh()
signal notify(text: String)

## 同行者(仲間)のひとこと。画面端の吹き出しに出る。
signal companion_say(text: String)

signal request_open_chest()
signal request_open_shop(shop_name: String, stock: PackedStringArray)
signal request_open_stall()
signal request_open_crafting()
signal request_close_menus()

## 店番(呼び込みミニゲーム)。started/ended は UI とホットバーの切り替えに、
## stats は店番中の売上表示の更新に使う。
signal request_start_tending()
signal tending_started()
signal tending_stats(customers: int, gold: int)
signal tending_ended()

