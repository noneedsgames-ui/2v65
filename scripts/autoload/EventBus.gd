extends Node
## グローバルイベント中継用のシングルトン。
## UI とワールド間の疎結合な通知に使う。

signal interact_prompt_show(text: String)
signal interact_prompt_hide()
signal notify(text: String)

signal request_open_house()
signal request_open_shop()
signal request_open_stall()
signal request_close_menus()

