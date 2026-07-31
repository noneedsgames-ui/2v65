extends Node
## グローバルイベント中継用のシングルトン。
## UI とワールド間の疎結合な通知に使う。

signal interact_prompt_show(text: String)
signal interact_prompt_hide()
signal notify(text: String)

## 同行者(仲間)のひとこと。画面端の吹き出しに出る。
signal companion_say(text: String)

signal request_open_chest()
signal request_open_shop(shop_name: String, stock: PackedStringArray)
signal request_open_stall()
signal request_open_crafting()
signal request_close_menus()

