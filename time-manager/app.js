/* 刻ノ帳 — 時間管理アプリ
 * タスク・集中タイマー(ポモドーロ式)・記録を、ブラウザの localStorage に保存する。
 * サーバー不要。index.html をブラウザで開けば動く。
 */
(() => {
  'use strict';

  const STORAGE_KEY = 'kokunocho.v1';
  const MIN = 60 * 1000;
  const MODE_LABEL = { focus: '集中', short: '小休憩', long: '長休憩' };

  const DEFAULT_STATE = {
    tasks: [],      // {id, title, estimate, done, createdAt, doneAt}
    sessions: [],   // {id, taskId, title, start, end}  ※集中した区切りのみ
    memos: [],        // {id, title, items:[{id, text, indent}], createdAt}
    activeMemoId: null,
    memoSessions: [], // {id, memoId, title, start, end}  ※メモ帳を使っていた時間
    settings: { focus: 25, short: 5, long: 15, longEvery: 4, autoStart: false, sound: true, notify: false, trackMemo: true },
    timer: { mode: 'focus', running: false, endAt: 0, remaining: 25 * MIN, duration: 25 * MIN, taskId: null, startedAt: 0, cycle: 0 },
  };

  // ---------- 保存 ----------
  function load() {
    try {
      const raw = JSON.parse(localStorage.getItem(STORAGE_KEY));
      if (!raw) return structuredClone(DEFAULT_STATE);
      return {
        tasks: Array.isArray(raw.tasks) ? raw.tasks : [],
        sessions: Array.isArray(raw.sessions) ? raw.sessions : [],
        memos: Array.isArray(raw.memos) ? raw.memos : [],
        activeMemoId: raw.activeMemoId ?? null,
        memoSessions: Array.isArray(raw.memoSessions) ? raw.memoSessions : [],
        settings: { ...DEFAULT_STATE.settings, ...raw.settings },
        timer: { ...DEFAULT_STATE.timer, ...raw.timer },
      };
    } catch {
      return structuredClone(DEFAULT_STATE);
    }
  }
  function save() { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }

  let state = load();
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);

  // ---------- 日付ユーティリティ ----------
  const dayKey = (t) => { const d = new Date(t); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`; };
  const startOfDay = (t) => { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); };
  const hhmm = (t) => new Date(t).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
  const fmtClock = (ms) => {
    const s = Math.max(0, Math.ceil(ms / 1000));
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  };
  const fmtMin = (ms) => {
    const m = Math.round(ms / MIN);
    return m >= 60 ? `${Math.floor(m / 60)}時間${m % 60}分` : `${m}分`;
  };

  // ---------- DOM ----------
  const $ = (id) => document.getElementById(id);
  const el = (tag, props = {}, ...kids) => {
    const n = document.createElement(tag);
    Object.assign(n, props);
    kids.forEach((k) => n.append(k));
    return n;
  };

  // ---------- タイマー ----------
  const T = () => state.timer;
  const modeDuration = (mode) => state.settings[mode] * MIN;
  const remainingNow = () => (T().running ? T().endAt - Date.now() : T().remaining);

  function setMode(mode, { keepRunning = false } = {}) {
    T().mode = mode;
    T().duration = modeDuration(mode);
    T().remaining = T().duration;
    T().running = false;
    T().startedAt = 0;
    if (keepRunning) start();
    save();
    renderTimer();
  }

  function start() {
    if (T().running) return;
    if (T().remaining <= 0) T().remaining = T().duration;
    T().running = true;
    T().endAt = Date.now() + T().remaining;
    if (!T().startedAt) T().startedAt = Date.now();
    save();
    renderTimer();
  }

  function pause() {
    if (!T().running) return;
    T().remaining = Math.max(0, T().endAt - Date.now());
    T().running = false;
    save();
    renderTimer();
  }

  function reset() {
    T().running = false;
    T().remaining = T().duration;
    T().startedAt = 0;
    save();
    renderTimer();
  }

  // 区切りを終える。completed=true は時間満了、false は「区切る」ボタン。
  function finishSegment(completed) {
    const elapsed = T().duration - Math.max(0, remainingNow());
    const wasFocus = T().mode === 'focus';

    if (wasFocus && (completed || elapsed >= MIN)) {
      const task = state.tasks.find((t) => t.id === T().taskId);
      // 閉じている間に満了していた場合も、本来の終了時刻で記録する
      const end = completed && T().running ? T().endAt : Date.now();
      state.sessions.push({
        id: uid(), taskId: task ? task.id : null, title: task ? task.title : '(タスクなし)',
        start: end - elapsed, end,
      });
      T().cycle += 1;
    }

    if (completed) alertEnd(wasFocus);

    let next = 'focus';
    if (wasFocus) next = T().cycle > 0 && T().cycle % state.settings.longEvery === 0 ? 'long' : 'short';
    setMode(next, { keepRunning: completed && state.settings.autoStart });
    renderAll();
  }

  function tick() {
    if (T().running && remainingNow() <= 0) finishSegment(true);
    renderTimer();
  }

  // ---------- 通知・音 ----------
  let audioCtx = null;
  function beep() {
    try {
      audioCtx = audioCtx || new AudioContext();
      [0, 0.25, 0.5].forEach((offset) => {
        const o = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        o.frequency.value = 880;
        g.gain.setValueAtTime(0.0001, audioCtx.currentTime + offset);
        g.gain.exponentialRampToValueAtTime(0.25, audioCtx.currentTime + offset + 0.02);
        g.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + offset + 0.2);
        o.connect(g).connect(audioCtx.destination);
        o.start(audioCtx.currentTime + offset);
        o.stop(audioCtx.currentTime + offset + 0.22);
      });
    } catch { /* 音が出せない環境では黙って続ける */ }
  }
  function alertEnd(wasFocus) {
    if (state.settings.sound) beep();
    if (state.settings.notify && 'Notification' in window && Notification.permission === 'granted') {
      new Notification(wasFocus ? '集中の区切りが終わりました' : '休憩が終わりました',
        { body: wasFocus ? 'ひと息つきましょう。' : '次の集中に戻りましょう。' });
    }
  }

  // ---------- タスク操作 ----------
  function addTask(title, estimate) {
    state.tasks.push({ id: uid(), title, estimate, done: false, createdAt: Date.now(), doneAt: null });
    if (!T().taskId) T().taskId = state.tasks.at(-1).id;
    save(); renderAll();
  }
  function toggleDone(id) {
    const t = state.tasks.find((x) => x.id === id);
    if (!t) return;
    t.done = !t.done;
    t.doneAt = t.done ? Date.now() : null;
    if (t.done && T().taskId === id) T().taskId = state.tasks.find((x) => !x.done)?.id ?? null;
    save(); renderAll();
  }
  function removeTask(id) {
    const t = state.tasks.find((x) => x.id === id);
    if (!t || !confirm(`「${t.title}」を削除しますか?(記録は残ります)`)) return;
    state.tasks = state.tasks.filter((x) => x.id !== id);
    if (T().taskId === id) T().taskId = null;
    save(); renderAll();
  }
  function selectTask(id) { T().taskId = id; save(); renderAll(); }

  const spentOn = (id) => state.sessions.filter((s) => s.taskId === id);

  // ---------- 描画 ----------
  const DIAL_LEN = 2 * Math.PI * 54;

  function renderTimer() {
    const rem = remainingNow();
    const { mode, running, duration, cycle } = T();
    $('timeLeft').textContent = fmtClock(rem);
    $('btnStart').textContent = running ? '一時停止' : (rem < duration ? '再開' : '開始');
    const bar = $('dialBar');
    bar.style.strokeDasharray = DIAL_LEN;
    bar.style.strokeDashoffset = DIAL_LEN * (1 - Math.max(0, rem) / duration);
    document.body.classList.toggle('resting', mode !== 'focus');
    document.querySelectorAll('.mode-tabs button').forEach((b) =>
      b.setAttribute('aria-selected', String(b.dataset.mode === mode)));
    const untilLong = state.settings.longEvery - (cycle % state.settings.longEvery);
    $('cycleInfo').textContent = `${MODE_LABEL[mode]} ・ 長休憩まであと${untilLong}回`;
    const task = state.tasks.find((t) => t.id === T().taskId);
    $('currentTask').textContent = task ? task.title : '(タスク未選択)';
    document.title = running ? `${fmtClock(rem)} ${MODE_LABEL[mode]} — 刻ノ帳` : '刻ノ帳 — 時間管理';
  }

  function taskItem(t) {
    const sessions = spentOn(t.id);
    const spent = sessions.reduce((a, s) => a + (s.end - s.start), 0);
    const li = el('li', { className: T().taskId === t.id && !t.done ? 'selected' : '' });
    const cb = el('input', { type: 'checkbox', checked: t.done, title: '完了' });
    cb.setAttribute('aria-label', `${t.title} を完了にする`);
    cb.addEventListener('change', () => toggleDone(t.id));
    const title = el('span', { className: 'task-title', textContent: t.title, title: 'クリックで集中の対象にする' });
    if (!t.done) title.addEventListener('click', () => selectTask(t.id));
    const meta = el('span', { className: 'task-meta', textContent: `${sessions.length}/${t.estimate}回 ・ ${fmtMin(spent)}` });
    const del = el('button', { className: 'icon-btn', textContent: '✕', title: '削除' });
    del.setAttribute('aria-label', `${t.title} を削除`);
    del.addEventListener('click', () => removeTask(t.id));
    li.append(cb, title, meta, del);
    return li;
  }

  function renderTasks() {
    const open = state.tasks.filter((t) => !t.done);
    const done = state.tasks.filter((t) => t.done).sort((a, b) => b.doneAt - a.doneAt);
    $('taskList').replaceChildren(...(open.length ? open.map(taskItem)
      : [el('li', { className: 'empty', textContent: 'タスクはまだありません。上の欄から追加してください。' })]));
    $('doneList').replaceChildren(...done.map(taskItem));
    $('doneCount').textContent = done.length;
  }

  function renderStats() {
    const today = startOfDay(Date.now());
    const todays = state.sessions.filter((s) => s.end >= today);
    $('statFocus').textContent = fmtMin(todays.reduce((a, s) => a + (s.end - s.start), 0));
    $('statCount').textContent = todays.length;
    $('statDone').textContent = state.tasks.filter((t) => t.done && t.doneAt >= today).length;
    renderMemoStat();

    // 今日の履歴(集中とメモ帳の使用をまとめて新しい順に。記録中のメモは閉じてから載せる)
    const memoToday = state.memoSessions.filter((s) => s.end >= today && s !== memoTrack.session);
    const all = [
      ...todays.map((s) => ({ s, kind: 'focus', label: s.title })),
      ...memoToday.map((s) => ({ s, kind: 'memo', label: `メモ「${memoTitle(s)}」` })),
    ].sort((a, b) => b.s.end - a.s.end);
    const list = all.map(({ s, kind, label }) => {
      const del = el('button', { className: 'icon-btn', textContent: '✕', title: 'この記録を消す' });
      del.addEventListener('click', () => {
        if (!confirm('この記録を消しますか?')) return;
        if (kind === 'focus') state.sessions = state.sessions.filter((x) => x.id !== s.id);
        else state.memoSessions = state.memoSessions.filter((x) => x.id !== s.id);
        save(); renderAll();
      });
      return el('li', { className: kind },
        el('span', { className: 'when', textContent: `${hhmm(s.start)}–${hhmm(s.end)}` }),
        el('span', { textContent: label }),
        el('span', { className: 'dur', textContent: fmtMin(s.end - s.start) }),
        del);
    });
    $('sessionList').replaceChildren(...(list.length ? list
      : [el('li', { className: 'empty', textContent: 'まだ記録がありません。' })]));

    renderWeekChart();
  }

  function weekData() {
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - i);
      days.push({ key: dayKey(d), date: d, min: 0, memo: 0 });
    }
    const byKey = Object.fromEntries(days.map((d) => [d.key, d]));
    state.sessions.forEach((s) => { const d = byKey[dayKey(s.end)]; if (d) d.min += (s.end - s.start) / MIN; });
    state.memoSessions.forEach((s) => { const d = byKey[dayKey(s.end)]; if (d) d.memo += (s.end - s.start) / MIN; });
    days.forEach((d) => { d.min = Math.round(d.min); d.memo = Math.round(d.memo); });
    return days;
  }

  function renderWeekChart() {
    const data = weekData();
    const svg = $('weekChart');
    const W = svg.clientWidth || 320, H = 180;
    const pad = { l: 32, r: 8, t: 18, b: 22 };
    const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
    const max = Math.max(30, ...data.map((d) => d.min));
    const step = max <= 60 ? 15 : max <= 120 ? 30 : max <= 300 ? 60 : 120;
    const top = Math.ceil(max / step) * step;
    const y = (v) => pad.t + ih - (v / top) * ih;
    const slot = iw / data.length;
    const bw = Math.min(28, slot - 2);   // 隣の棒とは最低2pxの間隔
    const NS = 'http://www.w3.org/2000/svg';
    const mk = (tag, attrs, text) => {
      const n = document.createElementNS(NS, tag);
      for (const k in attrs) n.setAttribute(k, attrs[k]);
      if (text != null) n.textContent = text;
      return n;
    };
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.replaceChildren();

    for (let v = 0; v <= top; v += step) {
      svg.append(mk('line', { class: 'grid', x1: pad.l, x2: W - pad.r, y1: y(v), y2: y(v) }));
      svg.append(mk('text', { class: 'axis-label', x: pad.l - 6, y: y(v) + 4, 'text-anchor': 'end' }, v));
    }

    const tip = $('chartTip');
    const best = data.reduce((a, d) => (d.min > a.min ? d : a), data[0]);
    data.forEach((d, i) => {
      const cx = pad.l + slot * i + slot / 2;
      const isToday = i === data.length - 1;
      const label = isToday ? '今日' : `${d.date.getMonth() + 1}/${d.date.getDate()}`;
      svg.append(mk('text', { class: 'axis-label', x: cx, y: H - 6, 'text-anchor': 'middle' }, label));

      const h = y(0) - y(d.min);
      let bar = null;
      if (d.min > 0) {
        // 上端だけ角を丸め、底は基線に揃える
        const r = Math.min(4, h, bw / 2), x0 = cx - bw / 2, y0 = y(d.min), yb = y(0);
        bar = mk('path', {
          class: 'bar',
          d: `M${x0},${yb} V${y0 + r} Q${x0},${y0} ${x0 + r},${y0} H${x0 + bw - r} Q${x0 + bw},${y0} ${x0 + bw},${y0 + r} V${yb} Z`,
        });
        svg.append(bar);
      }
      // 選択的な直接ラベル: 今日と最大の日だけ
      if (d.min > 0 && (isToday || d === best)) {
        svg.append(mk('text', { class: 'value-label', x: cx, y: y(d.min) - 5, 'text-anchor': 'middle' }, d.min));
      }
      // 棒より広いホバー領域
      const hit = mk('rect', { class: 'hit', x: pad.l + slot * i, y: pad.t, width: slot, height: ih });
      hit.addEventListener('mouseenter', () => {
        bar?.classList.add('hover');
        tip.hidden = false;
        tip.textContent = `${d.date.getMonth() + 1}月${d.date.getDate()}日 ・ ${d.min}分`;
        tip.style.left = `${(cx / W) * 100}%`;
        tip.style.top = `${(y(d.min) / H) * svg.clientHeight}px`;
      });
      hit.addEventListener('mouseleave', () => { bar?.classList.remove('hover'); tip.hidden = true; });
      svg.append(hit);
    });

    const rows = data.map((d) => el('tr', {},
      el('td', { textContent: d.date.toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' }) }),
      el('td', { textContent: `${d.min}分` }),
      el('td', { textContent: `${d.memo}分` })));
    $('weekTable').replaceChildren(el('tr', {},
      el('th', { textContent: '日付' }), el('th', { textContent: '集中時間' }), el('th', { textContent: 'メモ帳' })), ...rows);
  }

  function renderSettings() {
    const f = $('settingsForm');
    for (const [k, v] of Object.entries(state.settings)) {
      const input = f.elements[k];
      if (!input) continue;
      if (input.type === 'checkbox') input.checked = v; else input.value = v;
    }
  }

  function renderAll() {
    $('today').textContent = new Date().toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' });
    renderTimer(); renderTasks(); renderStats(); renderMemo();
  }

  // ---------- メモ帳(箇条書き・タブ) ----------
  const MAX_INDENT = 5;
  const MEMO_IDLE = 3 * MIN;      // 最後の操作からこれだけ経つと記録を止める
  const MEMO_MERGE = 60 * 1000;   // 直前の記録とこの間隔以内なら一続きとみなす
  const MEMO_MIN_KEEP = 5 * 1000; // これより短い記録は残さない

  const newItem = (text = '', indent = 0) => ({ id: uid(), text, indent });
  function ensureMemo() {
    if (!state.memos.length) {
      state.memos.push({ id: uid(), title: 'メモ1', items: [newItem()], createdAt: Date.now() });
    }
    if (!state.memos.some((m) => m.id === state.activeMemoId)) state.activeMemoId = state.memos[0].id;
    const m = activeMemo();
    if (!m.items.length) m.items.push(newItem());
  }
  const activeMemo = () => state.memos.find((m) => m.id === state.activeMemoId);
  const memoTitle = (s) => state.memos.find((m) => m.id === s.memoId)?.title ?? s.title;
  const memoMs = (memoId, since = 0) => state.memoSessions
    .filter((s) => s.memoId === memoId && s.end >= since)
    .reduce((a, s) => a + (s.end - s.start), 0);

  // --- 使用時間の記録 ---
  const memoTrack = { session: null, lastActivity: 0, lastSave: 0 };

  function closeMemoSession(at) {
    const s = memoTrack.session;
    if (!s) return;
    s.end = Math.max(s.start, Math.min(at, Date.now()));
    if (s.end - s.start < MEMO_MIN_KEEP) state.memoSessions = state.memoSessions.filter((x) => x !== s);
    memoTrack.session = null;
    save();
    renderStats();
    renderMemoClock();
  }

  function memoActivity() {
    if (!state.settings.trackMemo || document.hidden) return;
    const memo = activeMemo();
    if (!memo) return;
    const now = Date.now();
    memoTrack.lastActivity = now;
    if (memoTrack.session?.memoId === memo.id) { memoTrack.session.end = now; return; }
    closeMemoSession(now);
    // 少し前に同じタブを使っていたなら、その記録を延ばす
    const last = state.memoSessions.at(-1);
    if (last && last.memoId === memo.id && now - last.end <= MEMO_MERGE) {
      memoTrack.session = last;
      last.end = now;
    } else {
      memoTrack.session = { id: uid(), memoId: memo.id, title: memo.title, start: now, end: now };
      state.memoSessions.push(memoTrack.session);
    }
    save();
    renderMemoClock();
  }

  function memoTick() {
    const s = memoTrack.session;
    if (!s) return;
    const now = Date.now();
    const card = $('memoCard');
    const away = document.hidden || !document.hasFocus() || !card.contains(document.activeElement);
    if (away) { closeMemoSession(now); return; }
    if (now - memoTrack.lastActivity > MEMO_IDLE) { closeMemoSession(memoTrack.lastActivity); return; }
    s.end = now;
    if (now - memoTrack.lastSave > 5000) { memoTrack.lastSave = now; save(); }
    renderMemoClock();
  }

  function renderMemoClock() {
    const memo = activeMemo();
    if (!memo) return;
    const on = !!memoTrack.session;
    const st = $('memoStatus');
    st.classList.toggle('on', on);
    st.textContent = !state.settings.trackMemo ? '○ 記録しない設定です'
      : on ? '● 記録中' : '○ 停止中(書き始めると記録します)';
    $('memoTime').textContent =
      `このタブ: 今日 ${fmtMin(memoMs(memo.id, startOfDay(Date.now())))} ・ 累計 ${fmtMin(memoMs(memo.id))}`;
    renderMemoStat();
  }

  function renderMemoStat() {
    const today = startOfDay(Date.now());
    $('statMemo').textContent = fmtMin(state.memoSessions
      .filter((s) => s.end >= today).reduce((a, s) => a + (s.end - s.start), 0));
  }

  // --- タブ ---
  function renderMemoTabs() {
    const tabs = state.memos.map((m) => {
      const b = el('button', { className: 'memo-tab', textContent: m.title, title: 'ダブルクリックで名前を変える' });
      b.setAttribute('role', 'tab');
      b.setAttribute('aria-selected', String(m.id === state.activeMemoId));
      b.addEventListener('click', () => switchMemo(m.id));
      b.addEventListener('dblclick', () => renameMemo(m.id));
      return b;
    });
    const add = el('button', { className: 'memo-tab add', textContent: '+', title: '新しいタブ' });
    add.setAttribute('aria-label', '新しいタブを追加');
    add.addEventListener('click', addMemo);
    $('memoTabs').replaceChildren(...tabs, add);
  }

  function switchMemo(id) {
    if (id === state.activeMemoId) return;
    closeMemoSession(Date.now());
    state.activeMemoId = id;
    save();
    renderMemo();
    focusItem(activeMemo().items.at(-1).id, Infinity);
  }

  function addMemo() {
    const n = state.memos.length + 1;
    const m = { id: uid(), title: `メモ${n}`, items: [newItem()], createdAt: Date.now() };
    state.memos.push(m);
    switchMemo(m.id);
  }

  function renameMemo(id) {
    const m = state.memos.find((x) => x.id === id);
    const title = prompt('タブの名前', m.title)?.trim();
    if (!title) return;
    m.title = title.slice(0, 40);
    save(); renderMemo(); renderStats();
  }

  function deleteMemo() {
    const m = activeMemo();
    if (!confirm(`タブ「${m.title}」を削除しますか?(使用時間の記録は残ります)`)) return;
    closeMemoSession(Date.now());
    const i = state.memos.indexOf(m);
    state.memos.splice(i, 1);
    // 消したタブの記録には、その時点の名前を残しておく
    state.memoSessions.forEach((s) => { if (s.memoId === m.id) s.title = m.title; });
    state.activeMemoId = state.memos[Math.max(0, i - 1)]?.id ?? null;
    save(); renderMemo(); renderStats();
  }

  // --- 箇条書きの本体 ---
  function renderMemo() {
    ensureMemo();
    renderMemoTabs();
    const memo = activeMemo();
    $('memoList').replaceChildren(...memo.items.map((it) => {
      const input = el('input', { className: 'memo-input', value: it.text, placeholder: '…' });
      input.dataset.id = it.id;
      input.setAttribute('aria-label', `箇条書き(段 ${it.indent + 1})`);
      const li = el('li', {}, input);
      li.style.setProperty('--indent', it.indent);
      li.dataset.indent = it.indent;
      return li;
    }));
    renderMemoClock();
  }

  function focusItem(id, caret = 0) {
    const input = $('memoList').querySelector(`input[data-id="${id}"]`);
    if (!input) return;
    input.focus();
    const pos = Math.min(caret, input.value.length);
    input.setSelectionRange(pos, pos);
  }

  // 構造を変えたあとは描き直して、カーソルを戻す
  function commit(focusId, caret) {
    save();
    renderMemo();
    focusItem(focusId, caret);
  }

  function itemOf(input) {
    const items = activeMemo().items;
    const i = items.findIndex((x) => x.id === input.dataset.id);
    return { items, i, it: items[i] };
  }

  function onMemoKey(e) {
    const input = e.target;
    if (!input.classList.contains('memo-input')) return;
    if (e.isComposing || e.keyCode === 229) return; // 日本語の変換中は触らない
    const { items, i, it } = itemOf(input);
    const caret = input.selectionStart;
    const collapsed = input.selectionStart === input.selectionEnd;

    if (e.key === 'Enter') {
      e.preventDefault();
      // 空の行で Enter を押したら一段浅くする
      if (!it.text && it.indent > 0) { it.indent -= 1; commit(it.id, 0); return; }
      const after = it.text.slice(input.selectionEnd);
      it.text = it.text.slice(0, caret);
      const n = newItem(after, it.indent);
      items.splice(i + 1, 0, n);
      commit(n.id, 0);
    } else if (e.key === 'Tab') {
      e.preventDefault();
      if (e.shiftKey) it.indent = Math.max(0, it.indent - 1);
      else it.indent = Math.min(MAX_INDENT, i === 0 ? 0 : items[i - 1].indent + 1, it.indent + 1);
      commit(it.id, caret);
    } else if (e.key === 'Backspace' && collapsed && caret === 0) {
      if (it.indent > 0) { e.preventDefault(); it.indent -= 1; commit(it.id, 0); return; }
      if (i === 0) return;
      e.preventDefault();
      const prev = items[i - 1];
      const at = prev.text.length;
      prev.text += it.text;
      items.splice(i, 1);
      commit(prev.id, at);
    } else if (e.key === 'Delete' && collapsed && caret === it.text.length && i < items.length - 1) {
      e.preventDefault();
      it.text += items[i + 1].text;
      items.splice(i + 1, 1);
      commit(it.id, caret);
    } else if ((e.key === 'ArrowUp' || e.key === 'ArrowDown') && e.altKey) {
      // Alt+↑↓ で行を入れ替える
      e.preventDefault();
      const j = e.key === 'ArrowUp' ? i - 1 : i + 1;
      if (j < 0 || j >= items.length) return;
      [items[i], items[j]] = [items[j], items[i]];
      commit(it.id, caret);
    } else if (e.key === 'ArrowUp' && i > 0) {
      e.preventDefault(); focusItem(items[i - 1].id, caret);
    } else if (e.key === 'ArrowDown' && i < items.length - 1) {
      e.preventDefault(); focusItem(items[i + 1].id, caret);
    }
  }

  // 複数行の貼り付けは、行ごとの箇条書きに分ける(先頭の空白2つで一段)
  function onMemoPaste(e) {
    const input = e.target;
    if (!input.classList.contains('memo-input')) return;
    const text = e.clipboardData.getData('text/plain');
    if (!text.includes('\n')) return;
    e.preventDefault();
    const { items, i, it } = itemOf(input);
    const lines = text.replace(/\r/g, '').split('\n').filter((l) => l.trim());
    if (!lines.length) return;
    const parsed = lines.map((l) => {
      const lead = l.match(/^[ \t　]*/)[0].replace(/\t/g, '  ').replace(/　/g, '  ').length;
      const body = l.trim().replace(/^([-*+・•]|\d+[.)])\s*/, '');
      return { indent: Math.min(MAX_INDENT, it.indent + Math.floor(lead / 2)), body };
    });
    const head = it.text.slice(0, input.selectionStart);
    const tail = it.text.slice(input.selectionEnd);
    it.text = head + parsed[0].body;
    const extra = parsed.slice(1).map((p) => newItem(p.body, p.indent));
    items.splice(i + 1, 0, ...extra);
    const last = extra.at(-1) ?? it;
    const caret = last.text.length;
    last.text += tail;
    commit(last.id, caret);
  }

  function memoAsText() {
    return activeMemo().items.map((it) => `${'  '.repeat(it.indent)}- ${it.text}`).join('\n');
  }

  function bindMemo() {
    const card = $('memoCard');
    const list = $('memoList');
    list.addEventListener('keydown', onMemoKey);
    list.addEventListener('paste', onMemoPaste);
    list.addEventListener('input', (e) => {
      if (!e.target.classList.contains('memo-input')) return;
      itemOf(e.target).it.text = e.target.value;
      save();
    });
    // 空いているところをクリックしたら、最後の行に入る
    list.addEventListener('click', (e) => {
      if (e.target === list) focusItem(activeMemo().items.at(-1).id, Infinity);
    });
    ['focusin', 'input', 'keydown', 'pointerdown', 'wheel'].forEach((ev) =>
      card.addEventListener(ev, memoActivity, { passive: true }));
    $('memoDelete').addEventListener('click', deleteMemo);
    $('memoRename').addEventListener('click', () => renameMemo(state.activeMemoId));
    $('memoCopy').addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(memoAsText());
        $('memoCopy').textContent = 'コピーしました';
        setTimeout(() => { $('memoCopy').textContent = 'テキストでコピー'; }, 1500);
      } catch { alert('コピーできませんでした。'); }
    });
    document.addEventListener('visibilitychange', () => { if (document.hidden) closeMemoSession(Date.now()); });
    window.addEventListener('blur', () => closeMemoSession(Date.now()));
    window.addEventListener('pagehide', () => closeMemoSession(Date.now()));
    setInterval(memoTick, 1000);
  }

  // ---------- イベント ----------
  $('btnStart').addEventListener('click', () => (T().running ? pause() : start()));
  $('btnReset').addEventListener('click', reset);
  $('btnSkip').addEventListener('click', () => finishSegment(false));
  document.querySelectorAll('.mode-tabs button').forEach((b) =>
    b.addEventListener('click', () => {
      if (b.dataset.mode === T().mode) return;
      if (T().running && !confirm('進行中のタイマーを止めて切り替えますか?')) return;
      setMode(b.dataset.mode);
    }));

  document.addEventListener('keydown', (e) => {
    if (e.code !== 'Space' || e.target.closest('input, textarea, button, select, summary')) return;
    e.preventDefault();
    T().running ? pause() : start();
  });

  $('taskForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const title = $('taskTitle').value.trim();
    if (!title) return;
    addTask(title, Math.max(1, parseInt($('taskEst').value, 10) || 1));
    $('taskTitle').value = '';
    $('taskEst').value = 1;
  });

  $('settingsForm').addEventListener('change', (e) => {
    const input = e.target;
    const k = input.name;
    if (input.type === 'checkbox') {
      state.settings[k] = input.checked;
      if (k === 'trackMemo') { if (!input.checked) closeMemoSession(Date.now()); renderMemoClock(); }
      if (k === 'notify' && input.checked && 'Notification' in window && Notification.permission === 'default') {
        Notification.requestPermission();
      }
    } else {
      const v = Math.min(+input.max, Math.max(+input.min, parseInt(input.value, 10) || +input.min));
      input.value = v;
      state.settings[k] = v;
      // 止まっていて、まだ手を付けていない区切りなら新しい長さを反映する
      if (k === T().mode && !T().running && T().remaining === T().duration) setMode(k);
    }
    save(); renderTimer();
  });

  $('btnExport').addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
    const a = el('a', { href: URL.createObjectURL(blob), download: `kokunocho-${dayKey(Date.now())}.json` });
    a.click();
    URL.revokeObjectURL(a.href);
  });

  $('fileImport').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    e.target.value = '';
    if (!file) return;
    try {
      const data = JSON.parse(await file.text());
      if (!Array.isArray(data.tasks) || !Array.isArray(data.sessions)) throw new Error('形式が違います');
      if (!confirm('今のデータを読み込んだ内容で置き換えますか?')) return;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      memoTrack.session = null;
      state = load();
      T().running = false;
      save(); renderSettings(); renderAll();
    } catch (err) {
      alert(`読み込みに失敗しました: ${err.message}`);
    }
  });

  $('btnClear').addEventListener('click', () => {
    if (!confirm('タスク・記録・設定をすべて消去します。よろしいですか?')) return;
    memoTrack.session = null;
    state = structuredClone(DEFAULT_STATE);
    save(); renderSettings(); renderAll();
  });

  window.addEventListener('resize', renderWeekChart);

  // 日付が変わったら一覧と記録を描き直す
  let lastDay = dayKey(Date.now());
  setInterval(() => {
    tick();
    const now = dayKey(Date.now());
    if (now !== lastDay) { lastDay = now; renderAll(); }
  }, 250);

  // ---------- 起動 ----------
  // 閉じている間に時間が尽きていた区切りは、満了として処理する
  if (T().running && remainingNow() <= 0) finishSegment(true);
  bindMemo();
  renderSettings();
  renderAll();
})();
