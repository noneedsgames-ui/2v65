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

signal player_hp_changed(hp: int, max_hp: int)

## 村人との会話。resident_id と雑談候補を渡す。
signal request_open_dialogue(resident_id: String, idle_lines: PackedStringArray)
## 物語の会話。StoryDB の節 id を渡す。
signal request_open_story(node_id: String)
signal request_open_journal()
signal request_open_area_select()
signal request_open_system_menu()

signal request_open_chest()
signal request_open_shop(shop_name: String, stock: PackedStringArray)
signal request_open_stall()
## 工房を開く。bench が true なら家の作業台なので道具設計タブが使える。
signal request_open_workshop(bench: bool)
signal request_close_menus()

## 店番(呼び込みミニゲーム)。started/ended は UI とホットバーの切り替えに、
## stats は店番中の売上表示の更新に使う。
signal request_start_tending()
signal tending_started()
signal tending_stats(customers: int, gold: int)
signal tending_ended()

## 接客交渉。request は {"id": String, "qty": int, "unit_price": int}。
## finished の gold は成立額(不成立なら 0)。
signal request_open_negotiation(request: Dictionary)
signal negotiation_finished(gold: int, text: String)

