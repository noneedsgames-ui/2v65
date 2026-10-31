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
    settings: { focus: 25, short: 5, long: 15, longEvery: 4, autoStart: false, sound: true, notify: false },
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

    // 今日の履歴
    const list = todays.slice().reverse().map((s) => {
      const del = el('button', { className: 'icon-btn', textContent: '✕', title: 'この記録を消す' });
      del.addEventListener('click', () => {
        if (!confirm('この記録を消しますか?')) return;
        state.sessions = state.sessions.filter((x) => x.id !== s.id);
        save(); renderAll();
      });
      return el('li', {},
        el('span', { className: 'when', textContent: `${hhmm(s.start)}–${hhmm(s.end)}` }),
        el('span', { textContent: s.title }),
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
      days.push({ key: dayKey(d), date: d, min: 0 });
    }
    const byKey = Object.fromEntries(days.map((d) => [d.key, d]));
    state.sessions.forEach((s) => { const d = byKey[dayKey(s.end)]; if (d) d.min += (s.end - s.start) / MIN; });
    days.forEach((d) => { d.min = Math.round(d.min); });
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
      el('td', { textContent: `${d.min}分` })));
    $('weekTable').replaceChildren(el('tr', {}, el('th', { textContent: '日付' }), el('th', { textContent: '集中時間' })), ...rows);
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
    renderTimer(); renderTasks(); renderStats();
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
      state = load();
      T().running = false;
      save(); renderSettings(); renderAll();
    } catch (err) {
      alert(`読み込みに失敗しました: ${err.message}`);
    }
  });

  $('btnClear').addEventListener('click', () => {
    if (!confirm('タスク・記録・設定をすべて消去します。よろしいですか?')) return;
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
  renderSettings();
  renderAll();
})();
