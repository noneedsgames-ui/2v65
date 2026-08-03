extends Node
## 物語の台本。会話の節(ノード)と、どこで何が起きるかの対応表だけを持つ。
##
## 進行状態は Story が持ち、ここは読み取り専用のデータに徹する。
## こうしておくと、話を足すときにこのファイルだけを触ればよくなる。
##
## ── 節の書き方 ──
##   "speaker": 名前("" なら地の文)
##   "color":   名前の色
##   "pages":   ページ送りされる本文
##   "choices": 選択肢。無ければ「…」で閉じる
##   "route":   本文の代わりに、条件に合う節へそのまま飛ばす(分岐の合流点に使う)
##
## ── 選択肢 ──
##   "text":     ボタンの文字
##   "requires": 満たしていないと押せない条件。理由は "locked" に書く
##   "effects":  押したときに起きること
##   "goto":     次の節。空なら会話終了
##
## ── 条件(すべて満たす必要がある) ──
##   "chapter_min" / "chapter_max": 章の範囲
##   "flag": 立っていること / "not_flag": 立っていないこと
##   "flag_is": {旗: 値} 旗が特定の値であること
##   "flag_at_least": {旗: 数} 数えている旗の下限
##   "items": {id: 個数}
##   "natures": {"nature": 性質, "kinds": 種類数}  その性質を持つ素材を何種類持っているか
##   "mana": {"nature": 性質, "total": 魔力}       その性質の素材の魔力合計
##   "brews_at_least": 調合の発見数
##   "tool_built": 組み上げた道具の id
##   "area": いまの探索地
##
## ── 効果 ──
##   "set": {旗: 値} / "add": {旗: 増分} / "chapter": 章を進める
##   "take": {id: 個数} / "take_natures": 条件と同じ形で消費 / "take_mana": 同上
##   "give": {id: 個数} / "gold": 増減
##   "notify": 画面下の通知 / "say": 相棒のひとこと

const NAME_COLOR := Color(1, 0.85, 0.4)
const NARRATION_COLOR := Color(0.78, 0.8, 0.86)
const COMPANION_COLOR := Color(0.6, 0.85, 1)

## 章立て。メモ帳の「物語」タブに出る。
## chapter は Story.chapter と同じ番号で、0 はまだ始まっていない状態。
const CHAPTERS := [
	{"chapter": 1, "title": "一章 枯れる草", "hint": "ノナに話しかけよう。〈潤〉の素材を集めてほしいそうだ。"},
	{"chapter": 2, "title": "二章 炉の底", "hint": "ゴルドーに話しかけよう。〈輝〉を帯びた鉱石が要る。"},
	{"chapter": 3, "title": "三章 頁のあいだ", "hint": "町に来た司書ヴェスパを訪ねよう。調合をいくつか覚えてから。"},
	{"chapter": 4, "title": "四章 灯芯", "hint": "家の作業台で坑夫のランプを組み上げ、ヴェスパに見せよう。"},
	{"chapter": 5, "title": "五章 霊峰の灯", "hint": "陽昇る霊峰へ登り、消えかけの灯のもとへ。"},
	{"chapter": 6, "title": "終章 灯を継ぐ", "hint": "町へ戻ろう。広場にみんなが待っている。"},
	{"chapter": 7, "title": "── 完 ──", "hint": "旅は続く。町の灯は、あなたの選んだかたちで燃えている。"},
]

## 場所で起きる出来事。StoryTrigger の event_id からここを引く。
## "once": true なら記録に残して二度と起きない。
## false のものは条件が外れる(章が進む・旗が立つ)ことで自然に止まる。
const EVENTS := {
	"town_arrive": {"node": "p_arrive", "requires": {"chapter_max": 0}, "once": true},
	"home_rest": {"node": "h_home", "requires": {"chapter_min": 1, "not_flag": "home_talk"}, "once": true},
	"cavern_whisper": {"node": "c_whisper", "once": false,
		"requires": {"chapter_min": 2, "chapter_max": 2, "area": "cavern", "not_flag": "heard_voice"}},
	"peak_beacon": {"node": "k_beacon", "once": false,
		"requires": {"chapter_min": 5, "chapter_max": 5, "area": "peak"}},
	"town_ending": {"node": "e_return", "once": false,
		"requires": {"chapter_min": 6, "chapter_max": 6}},
}

## 村人に話しかけたとき、依頼画面より先に出す節。
## 上から順に見て、条件に合う最初のものが選ばれる。合うものが無ければ従来の依頼画面。
##
## "once": true の節は一度見たら飛ばす。そうしないと世間話が居座って、
## その村人の依頼をいつまでも受けられなくなる。
## 依頼と受け渡しの節(n_ask / g_wait など)は繰り返し出したいので付けない。
const RESIDENT_NODES := {
	"nona": [
		{"requires": {"chapter_min": 1, "chapter_max": 1, "not_flag": "nona_asked"}, "node": "n_ask"},
		{"requires": {"chapter_min": 1, "chapter_max": 1, "flag": "nona_asked"}, "node": "n_wait"},
		{"requires": {"chapter_min": 2, "flag": "nona_gift"}, "node": "n_after_gift", "once": true},
		{"requires": {"chapter_min": 2, "flag": "nona_paid"}, "node": "n_after_paid", "once": true},
	],
	"gordo": [
		{"requires": {"chapter_min": 2, "chapter_max": 2, "not_flag": "gordo_asked"}, "node": "g_ask"},
		{"requires": {"chapter_min": 2, "chapter_max": 2, "flag": "gordo_asked"}, "node": "g_wait"},
		{"requires": {"chapter_min": 3}, "node": "g_after", "once": true},
	],
	"vespa": [
		{"requires": {"chapter_max": 2}, "node": "v_early", "once": true},
		{"requires": {"chapter_min": 3, "chapter_max": 3}, "node": "v_lore"},
		{"requires": {"chapter_min": 4, "chapter_max": 4}, "node": "v_lamp"},
		{"requires": {"chapter_min": 5}, "node": "v_after", "once": true},
	],
	"mira": [
		{"requires": {"chapter_min": 5, "chapter_max": 6}, "node": "m_worry", "once": true},
		{"requires": {"chapter_min": 7}, "node": "m_after", "once": true},
	],
	"lupe": [
		{"requires": {"chapter_min": 3, "chapter_max": 6}, "node": "l_talk", "once": true},
		{"requires": {"chapter_min": 7}, "node": "l_after", "once": true},
	],
}

## 会話の本体。
## 文字列は連結せず一行で書く。const の中で式を組み立てないようにするため。
const NODES := {

# ────────── 序章 ──────────
"p_arrive": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"町の広場のまんなかに、背の低い石の柱が立っている。てっぺんの硝子の中で、小さな灯がひとつ、消えかけの蝋燭のように揺れていた。",
		"通りかかった誰もが、それを見ないふりで通り過ぎていく。",
	],
	"choices": [
		{"text": "灯を覗きこむ", "effects": {"set": {"curious": true}}, "goto": "p_look"},
		{"text": "気にせず先へ行く", "goto": "p_pass"},
	],
},
"p_look": {
	"speaker": "相棒", "color": COMPANION_COLOR,
	"pages": [
		"「……弱ってるね、この灯」",
		"「町の魔力は、ぜんぶこの灯から回ってるんだって。薬草が育つのも、鉱脈が実るのも、もとはこれ」",
		"「消えたらどうなるか、ぼくは知らない。知りたくもないけど」",
	],
	"choices": [
		{"text": "誰かに聞いてみよう", "goto": "",
			"effects": {"chapter": 1, "add": {"faith": 1}, "say": "薬草売りのノナさんなら、草の変化に気づいてるかも。"}},
	],
},
"p_pass": {
	"speaker": "相棒", "color": COMPANION_COLOR,
	"pages": [
		"「……ねえ。いまの灯、見た？」",
		"「見なかったことにしてもいいけど。ぼくは、たぶん忘れられない」",
	],
	"choices": [
		{"text": "やっぱり気になる", "goto": "",
			"effects": {"chapter": 1, "set": {"curious": true}, "say": "でしょ。ノナさんなら草の変化に気づいてるはずだよ。"}},
		{"text": "商売が先だ", "goto": "",
			"effects": {"chapter": 1, "say": "……わかった。でも、いつか行こうね。"}},
	],
},

# ────────── 一章 枯れる草 ──────────
"n_ask": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": [
		"「あんた、ちょうどいいところに来た。これ見てごらん」",
		"差し出された籠の中で、瑞々しいはずの薬草が、水気を失って紙のように白茶けている。",
		"「潤いの草がこうなるのはね、土のせいじゃない。魔力が痩せてるんだよ。……広場の灯、見たかい」",
	],
	"choices": [
		{"text": "見た。弱っていた", "requires": {"flag": "curious"}, "locked": "広場の灯をちゃんと見ていない",
			"effects": {"add": {"faith": 1}, "set": {"nona_asked": true}, "say": "話が早いね。"}, "goto": "n_task"},
		{"text": "灯がどうかしたのか", "effects": {"set": {"nona_asked": true}}, "goto": "n_task"},
	],
},
"n_task": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": [
		"「調べたいんだ。まだ生きてる〈潤〉の素材を、種類ちがいで三つ持ってきておくれ。同じものを三つじゃ意味がないよ、三種類だ」",
		"「森でも岩窟でも霊峰でも、潤を帯びたものならなんでもいい。工房の図鑑で「潤」を引けば、どこで採れるか書いてある」",
	],
	"choices": [
		{"text": "わかった、探してくる", "effects": {"notify": "〈潤〉の素材を3種類集めよう"}, "goto": ""},
	],
},
"n_wait": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": ["「〈潤〉の素材、三種類そろったかい」"],
	"choices": [
		{"text": "これでどうだ(3種を渡す)", "requires": {"natures": {"nature": "moist", "kinds": 3}},
			"locked": "〈潤〉の素材が3種類そろっていない",
			"effects": {"take_natures": {"nature": "moist", "kinds": 3}}, "goto": "n_pay"},
		{"text": "まだだ", "goto": ""},
	],
},
"n_pay": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": [
		"ノナは三つの草を並べ、順に指の腹でこすっては、匂いを嗅いだ。",
		"「……やっぱりだ。どれも芯まで乾いてる。町のまわりぜんぶで、潤の魔力が抜けていってる」",
		"「手間賃を払うよ。いくらでも言いな」",
	],
	"choices": [
		{"text": "代金はいらない", "goto": "n_gift",
			"effects": {"add": {"faith": 2}, "set": {"nona_gift": true}, "chapter": 2,
				"give": {"catalyst_salt": 3}, "say": "かっこつけちゃって。……でも、いいと思う。"}},
		{"text": "相応の額をもらう", "goto": "n_paid",
			"effects": {"gold": 220, "set": {"nona_paid": true}, "chapter": 2,
				"say": "商売だもんね。悪いことじゃないよ。"}},
	],
},
"n_gift": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": [
		"「……ふん。そういうのは嫌いじゃないよ」",
		"押しつけるように、白い粉の包みを三つ握らされた。錬成塩だ。",
		"「金より役に立つ。次は鍛冶のゴルドーに聞いてごらん。あいつも炉の火が細るって、ずっとぼやいてる」",
	],
	"choices": [{"text": "ありがとう", "goto": ""}],
},
"n_paid": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": [
		"「はい、二百二十。きっちり数えな」",
		"「……悪く思っちゃいないよ。ただ働きさせる方がどうかしてる」",
		"「次は鍛冶のゴルドーだ。あいつも炉の火が細るってぼやいてる」",
	],
	"choices": [{"text": "行ってみる", "goto": ""}],
},
"n_after_gift": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": ["「あんたが持ってきた草、乾かないように寝かせてあるよ。……借りは返すからね」"],
	"choices": [{"text": "またね", "goto": ""}],
},
"n_after_paid": {
	"speaker": "ノナ", "color": NAME_COLOR,
	"pages": ["「金は払った。貸し借りなしだ。……それでいいんだろう？」"],
	"choices": [{"text": "ああ", "goto": ""}],
},

# ────────── 二章 炉の底 ──────────
"g_ask": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": [
		"「……ノナから聞いたか」",
		"炉を覗きこむと、火は赤いのに、鉄がいっこうに色を変えない。",
		"「熱は足りてる。足りてないのは〈輝〉だ。光を帯びた鉱石を、魔力にして十以上ぶん持ってこい。数じゃない、魔力の合計だ」",
		"「霊峰か岩窟だな。強いのを一つでも、弱いのを幾つでもいい」",
	],
	"choices": [
		{"text": "掘ってくる", "goto": "",
			"effects": {"set": {"gordo_asked": true}, "notify": "〈輝〉の素材を魔力10以上ぶん集めよう"}},
		{"text": "灯のことを聞く", "goto": "g_lore"},
	],
},
"g_lore": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": [
		"「灯か。……俺の親父が芯を替えたのが最後だ。四十年前になる」",
		"「作り方は俺も知らん。親父は最後まで教えなかった。教える前に手が止まった」",
		"「町に司書が来るという話だ。あれなら記録を持ってるかもしれん」",
	],
	"choices": [
		{"text": "掘ってくる", "goto": "",
			"effects": {"set": {"gordo_asked": true}, "notify": "〈輝〉の素材を魔力10以上ぶん集めよう"}},
	],
},
"g_wait": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": ["「輝の石だ。魔力で十以上。……持ってきたか」"],
	"choices": [
		{"text": "これでいいか(渡す)", "requires": {"mana": {"nature": "bright", "total": 10}},
			"locked": "〈輝〉の素材が魔力10ぶんに足りない",
			"effects": {"take_mana": {"nature": "bright", "total": 10}}, "goto": "g_forge"},
		{"text": "まだだ", "goto": ""},
	],
},
"g_forge": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": [
		"石を炉に落とすと、赤かった火が一瞬だけ白く抜けた。鉄が、ようやく素直な色に変わっていく。",
		"「……久しぶりだ、この色は」",
		"「どこで掘った。岩窟か」",
	],
	"choices": [
		{"text": "岩窟で聞いた声のことを話す", "requires": {"flag": "heard_voice"},
			"locked": "岩窟でまだ何も聞いていない",
			"effects": {"add": {"faith": 1}, "set": {"told_gordo": true}, "chapter": 3}, "goto": "g_voice"},
		{"text": "正直に道のりを話す", "effects": {"add": {"faith": 1}, "chapter": 3}, "goto": "g_done"},
		{"text": "適当にはぐらかす", "effects": {"set": {"hid_source": true}, "chapter": 3}, "goto": "g_done"},
	],
},
"g_voice": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": [
		"金槌を持つ手が止まった。",
		"「……親父も同じことを言ってた。岩の奥で誰かが呼ぶ、と」",
		"「司書が来てる。広場の東だ。あれなら記録を持ってる。行け」",
	],
	"choices": [{"text": "行ってみる", "effects": {"say": "司書さんだって。広場の東だね。"}, "goto": ""}],
},
"g_done": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": [
		"「そうか。……まあいい」",
		"「司書が来てる。広場の東だ。灯のことなら、あれに聞け」",
	],
	"choices": [{"text": "わかった", "effects": {"say": "司書さんだって。広場の東だね。"}, "goto": ""}],
},
"g_after": {
	"speaker": "ゴルドー", "color": NAME_COLOR,
	"pages": ["「炉は戻った。……お前のおかげだとは言わんぞ」"],
	"choices": [{"text": "またね", "goto": ""}],
},

# ────────── 岩窟の出来事 ──────────
"c_whisper": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"岩の裂け目の奥から、水が滴るような音がする。よく聞くと、それは音ではなく、言葉の切れ端のようだった。",
		"「……つ……ぎ……」",
	],
	"choices": [
		{"text": "裂け目に耳を寄せる", "effects": {"set": {"heard_voice": true}, "add": {"faith": 1}}, "goto": "c_listen"},
		{"text": "聞かなかったことにする", "effects": {"set": {"heard_voice": true}}, "goto": "c_ignore"},
	],
},
"c_listen": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"「つ、ぎ、を、た、の、む」",
		"言葉が終わると、裂け目はただの岩の割れ目に戻った。手を入れてみても、冷たい風が指を撫でるだけだ。",
	],
	"choices": [{"text": "……", "effects": {"say": "いまの、聞こえた？ ……ぼくにも聞こえた。"}, "goto": ""}],
},
"c_ignore": {
	"speaker": "相棒", "color": COMPANION_COLOR,
	"pages": [
		"「行こう。……うん、行こう」",
		"大きな背中が、いつもより早足で前を歩いていく。",
	],
	"choices": [{"text": "後を追う", "goto": ""}],
},

# ────────── 家での夜 ──────────
"h_home": {
	"speaker": "相棒", "color": COMPANION_COLOR,
	"pages": [
		"「ねえ。ひとつ聞いていい？」",
		"「灯が消えたら、この家はどうなるのかな。……ぼくたち、ここに住んでていいのかな」",
	],
	"choices": [
		{"text": "ここは君の家でもある", "goto": "",
			"effects": {"set": {"home_talk": true}, "add": {"faith": 1}, "say": "……うん。ありがとう。"}},
		{"text": "灯は消させない", "goto": "",
			"effects": {"set": {"home_talk": true}, "add": {"faith": 1}, "say": "そう言うと思った。じゃあ、ぼくも手伝う。"}},
		{"text": "わからない", "goto": "",
			"effects": {"set": {"home_talk": true}, "say": "……そうだね。わからないよね。"}},
	],
},

# ────────── 三章 頁のあいだ ──────────
"v_early": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"「まだ荷を解いている最中です。棚が足りない。椅子も足りない」",
		"「用があるなら、もう少し後にしていただけますか」",
	],
	"choices": [{"text": "また来る", "goto": ""}],
},
"v_lore": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"「灯のことですね。……ええ、記録はあります」",
		"「ただし、読んでも意味が取れないでしょう。魔力の性質と並びを、自分の手で確かめたことがない人には」",
		"「調合をいくつか覚えてから、もう一度いらしてください。三つも成功していれば十分です」",
	],
	"choices": [
		{"text": "もう覚えている", "requires": {"brews_at_least": 3},
			"locked": "調合をまだ3種類も成功させていない",
			"effects": {"set": {"read_lore": true}}, "goto": "v_read"},
		{"text": "出直す", "goto": ""},
	],
},
"v_read": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"分厚い綴じ本が机に広げられる。ページの端が焦げていた。",
		"「灯は燃えているのではありません。魔力の回路が閉じている、それだけです」",
		"「回路の芯には〈輝〉を、外殻には〈堅〉を、火袋には〈熱〉を。──これ、どこかで見た並びではありませんか」",
	],
	"choices": [
		{"text": "坑夫のランプと同じだ", "effects": {"add": {"faith": 1}}, "goto": "v_lamp_hint"},
		{"text": "なぜ灯は消えるのか", "goto": "v_why"},
		{"text": "見当がつかない", "goto": "v_lamp_hint"},
	],
},
"v_why": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"「芯が焼き切れるからです。四十年ももてば上等でしょう」",
		"「本当の問題は、替える人がいないことです。回路をつなげる者が、この町からいなくなった」",
		"「前に替えたのは、鍛冶屋の先代だそうですね」",
	],
	"choices": [{"text": "……続けて", "goto": "v_lamp_hint"}],
},
"v_lamp_hint": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"「坑夫のランプ。あれと同じ構えです。小さな灯を、大きな灯に写す」",
		"「家の作業台で一つ組み上げて、持ってきてください。回路の通し方は、組んだ人の手が覚えます」",
	],
	"choices": [
		{"text": "作ってくる", "goto": "",
			"effects": {"chapter": 4, "notify": "家の作業台で坑夫のランプを組もう"}},
	],
},

# ────────── 四章 灯芯 ──────────
"v_lamp": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": ["「坑夫のランプは組み上がりましたか」"],
	"choices": [
		{"text": "できた(見せる)", "requires": {"tool_built": "miners_lamp"},
			"locked": "まだ坑夫のランプを組み上げていない", "goto": "v_lamp_ok"},
		{"text": "まだだ", "goto": ""},
	],
},
"v_lamp_ok": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"ヴェスパはランプを両手で受け取り、灯芯のあたりを長く見ていた。",
		"「……ええ。手が覚えています。この回路なら通せる」",
		"「灯の本体は町にはありません。陽昇る霊峰の頂、雲より上の岩棚に、元の灯が立っています」",
		"「登ってください。あなたの灯を、あちらに継いでくるのです」",
	],
	"choices": [
		{"text": "行ってくる", "goto": "",
			"effects": {"chapter": 5, "notify": "陽昇る霊峰へ登ろう", "say": "霊峰か。……気をつけて行こうね。"}},
	],
},
"v_after": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": ["「記録の続きを書いています。今度はあなたの名前が入る番です」"],
	"choices": [{"text": "またね", "goto": ""}],
},

# ────────── ほかの住民のひとこと ──────────
"m_worry": {
	"speaker": "ミラ", "color": NAME_COLOR,
	"pages": [
		"「窯の火が、前より粘らないんだよ。パイの底が生焼けでね」",
		"「あんた、灯のことで走り回ってるんだろ。……焼けたら持っていきな」",
	],
	"choices": [{"text": "ありがとう", "goto": ""}],
},
"m_after": {
	"speaker": "ミラ", "color": NAME_COLOR,
	"pages": ["「窯が戻ったよ。底までこんがりだ。……はい、これは景気づけ」"],
	"choices": [
		{"text": "いただく", "goto": "", "effects": {"give": {"berry_pie": 1}}},
	],
},
"l_talk": {
	"speaker": "ルーペ", "color": NAME_COLOR,
	"pages": [
		"「灯の柱ね。あれを彫ったのは私の師匠の師匠だよ」",
		"「石は減らない。減るのは、直せる人のほうさ」",
	],
	"choices": [{"text": "……なるほど", "goto": ""}],
},
"l_after": {
	"speaker": "ルーペ", "color": NAME_COLOR,
	"pages": ["「柱の台座、彫り直しておいたよ。名前を入れる場所も空けてある」"],
	"choices": [{"text": "またね", "goto": ""}],
},

# ────────── 五章 霊峰の灯 ──────────
"k_beacon": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"雲を抜けた岩棚に、町のものとよく似た石の柱が立っていた。ただし背丈は三倍あり、硝子は割れ、中の灯は指先ほどに縮んでいる。",
		"手のひらをかざすと、細い糸のような魔力がこちらへ伸びてきて、ためらうように止まった。",
		"継ぐには、誰かの魔力を通さなければならない。",
	],
	"choices": [
		{"text": "自分の魔力を通す", "requires": {"flag_at_least": {"faith": 4}},
			"locked": "灯がまだあなたを信じていない(人に向き合った回数が足りない)",
			"effects": {"set": {"ending": "self"}, "chapter": 6}, "goto": "k_self"},
		{"text": "相棒に頼む", "effects": {"set": {"ending": "companion"}, "chapter": 6}, "goto": "k_companion"},
		{"text": "灯を外して持ち帰る", "effects": {"set": {"ending": "carry"}, "chapter": 6}, "goto": "k_carry"},
	],
},
"k_self": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"手を差し入れる。焼けるかと思ったが、熱くはなかった。ただ、ひどく懐かしい匂いがした。",
		"糸が指に絡み、太くなり、硝子の内側でふくらんで、岩棚ぜんぶを白く照らした。",
		"眼下、雲の切れ間のずっと下で、町の広場の点がひとつ、同じ色に灯るのが見えた。",
	],
	"choices": [{"text": "町へ戻る", "effects": {"say": "……見えた？ 町が、光った。"}, "goto": ""}],
},
"k_companion": {
	"speaker": "相棒", "color": COMPANION_COLOR,
	"pages": [
		"「ぼくがやる」",
		"止める間もなく、大きな手が硝子の中に沈んだ。背中の輪郭が、内側から光でふちどられる。",
		"「……平気だよ。ぼくは大きいから、少しくらい分けても減らない」",
		"灯は満ちた。相棒の毛先が、しばらくのあいだ薄く光っていた。",
	],
	"choices": [{"text": "町へ戻る", "effects": {"say": "ね、言ったでしょ。ぼくは大きいんだから。"}, "goto": ""}],
},
"k_carry": {
	"speaker": "", "color": NARRATION_COLOR,
	"pages": [
		"柱の根元をたどると、灯の器は思ったより簡単に外れた。",
		"消えかけの灯を抱えて岩棚を降りる。背中で、空になった柱が風に鳴っていた。",
		"これでいい。少なくとも、灯はまだ手の中にある。",
	],
	"choices": [{"text": "町へ戻る", "effects": {"say": "……うん。持って帰ろう。それも答えだ。"}, "goto": ""}],
},

# ────────── 終章 ──────────
## 広場に着いたら、霊峰で選んだ答えに応じて分かれる。
"e_return": {
	"route": [
		{"requires": {"flag_is": {"ending": "self"}}, "goto": "e_self"},
		{"requires": {"flag_is": {"ending": "companion"}}, "goto": "e_companion"},
		{"goto": "e_carry"},
	],
},
"e_self": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"広場に人が集まっていた。ノナも、ゴルドーも、ヴェスパもいる。柱の硝子は、四十年ぶりの白い光で満ちていた。",
		"「灯が戻りました。二代目です」",
		"ノナが籠を突き出す。中の薬草は瑞々しさを取り戻していた。ゴルドーは何も言わず、新しく打った金具をひとつ、こちらの手に押しつけた。",
		"「記録に書いておきます。──この町の灯を継いだ人のことを」",
	],
	"choices": [
		{"text": "旅は続く", "goto": "",
			"effects": {"chapter": 7, "gold": 600, "give": {"catalyst_prima": 3, "miners_lamp": 1},
				"notify": "物語「消えかけの灯」を見届けた", "say": "おつかれさま。……また、どこか行こうね。"}},
	],
},
"e_companion": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"広場に人が集まっていた。柱の硝子の中で、少し黄みがかった灯が静かに揺れている。",
		"「灯が戻りました。……ずいぶん温かい灯だ」",
		"広場の隅で、相棒が子どもたちに囲まれている。毛先の薄い光を指さされて、困ったように身をよじっていた。",
		"「あの子の名前も、記録に入れてよろしいですか」",
	],
	"choices": [
		{"text": "もちろん", "goto": "",
			"effects": {"chapter": 7, "gold": 480, "give": {"catalyst_prima": 2, "berry_pie": 3},
				"notify": "物語「消えかけの灯」を見届けた", "say": "ぼくの名前、書いてもらっちゃった。えへへ。"}},
	],
},
"e_carry": {
	"speaker": "ヴェスパ", "color": NAME_COLOR,
	"pages": [
		"抱えてきた灯を柱に据えると、硝子の中で小さな火が息を吹き返した。ただし、以前ほどの明るさはない。",
		"「……持ち帰ったのですね。柱ごと運べる人は、そういません」",
		"「灯は小さいままです。でも、消えてはいない。次に継ぐ人が現れるまで、これで足ります」",
	],
	"choices": [
		{"text": "それでいい", "goto": "",
			"effects": {"chapter": 7, "gold": 520, "give": {"catalyst_quick": 4},
				"notify": "物語「消えかけの灯」を見届けた", "say": "……うん。ぼくは、これでよかったと思う。"}},
	],
},
}

func get_node_data(id: String) -> Dictionary:
	return NODES.get(id, {})

func has_node_data(id: String) -> bool:
	return NODES.has(id)

func get_event(event_id: String) -> Dictionary:
	return EVENTS.get(event_id, {})

func resident_entries(resident_id: String) -> Array:
	return RESIDENT_NODES.get(resident_id, [])

func chapter_title(chapter: int) -> String:
	for c in CHAPTERS:
		if int(c["chapter"]) == chapter:
			return c["title"]
	return ""

func chapter_hint(chapter: int) -> String:
	for c in CHAPTERS:
		if int(c["chapter"]) == chapter:
			return c["hint"]
	return ""
