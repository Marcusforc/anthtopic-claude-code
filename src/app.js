import { parseCommand, a1ToGrid } from './parser.js';
import { SheetsClient } from './sheets.js';

const $ = (id) => document.getElementById(id);
const store = {
  get: (k) => { try { return localStorage.getItem(k) ?? ''; } catch { return ''; } },
  set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* приватный режим */ } },
};

let token = '';
let tokenClient;
let activeSheet = 'Лист1';
const undoStack = [];
const client = new SheetsClient(() => token);

function spreadsheetId() {
  const v = $('sheet').value.trim();
  return v.match(/\/d\/([\w-]+)/)?.[1] ?? v;
}

function log(kind, msg) {
  const li = document.createElement('li');
  li.className = kind;
  li.textContent = msg;
  $('log').prepend(li);
}

function say(msg) {
  if ($('speak').checked && 'speechSynthesis' in window) {
    const u = new SpeechSynthesisUtterance(msg);
    u.lang = 'ru-RU';
    speechSynthesis.speak(u);
  }
}

function signIn() {
  const clientId = $('clientId').value.trim();
  if (!clientId) return log('err', 'Укажите OAuth Client ID');
  store.set('clientId', clientId);
  tokenClient = google.accounts.oauth2.initTokenClient({
    client_id: clientId,
    scope: 'https://www.googleapis.com/auth/spreadsheets',
    callback: (r) => {
      if (r.error) return log('err', `Ошибка входа: ${r.error}`);
      token = r.access_token;
      $('status').textContent = 'Вход выполнен';
      log('ok', 'Вход выполнен');
    },
  });
  tokenClient.requestAccessToken();
}

async function snapshot(id, range) {
  // FORMULA, чтобы отмена возвращала формулы, а не вычисленные значения
  return { id, sheet: activeSheet, range, values: await client.getValues(id, activeSheet, range, 'FORMULA') };
}

async function execute(cmd) {
  const id = spreadsheetId();
  if (!token) throw new Error('Сначала войдите в Google');
  if (!id) throw new Error('Укажите таблицу');

  switch (cmd.type) {
    case 'write': {
      undoStack.push(await snapshot(id, cmd.cell));
      await client.setValues(id, activeSheet, cmd.cell, [[cmd.value]]);
      return `${cmd.cell} = ${cmd.value}`;
    }
    case 'read': {
      const rows = await client.getValues(id, activeSheet, cmd.range);
      const text = rows.length ? rows.map((r) => r.join(', ')).join('; ') : 'пусто';
      return `${cmd.range}: ${text}`;
    }
    case 'clear': {
      undoStack.push(await snapshot(id, cmd.range));
      await client.clear(id, activeSheet, cmd.range);
      return `Очищено ${cmd.range}`;
    }
    case 'append': {
      const res = await client.append(id, activeSheet, [cmd.row]);
      undoStack.push({ id, sheet: activeSheet, range: res.updates.updatedRange.split('!')[1], values: [] });
      return `Добавлена строка: ${cmd.row.join(', ')}`;
    }
    case 'aggregate': {
      if (cmd.target) {
        undoStack.push(await snapshot(id, cmd.target));
        await client.setValues(id, activeSheet, cmd.target, [[`=${cmd.fn}(${cmd.range})`]]);
        return `${cmd.target} = ${cmd.fn}(${cmd.range})`;
      }
      const nums = (await client.getValues(id, activeSheet, cmd.range, 'UNFORMATTED_VALUE'))
        .flat().filter((v) => typeof v === 'number');
      const sum = nums.reduce((a, b) => a + b, 0);
      const result = {
        SUM: sum,
        AVERAGE: nums.length ? sum / nums.length : 0,
        MAX: Math.max(...nums),
        MIN: Math.min(...nums),
        COUNT: nums.length,
      }[cmd.fn];
      return `${cmd.fn}(${cmd.range}) = ${result}`;
    }
    case 'bold': {
      const sheetId = (await client.sheets(id)).find((s) => s.title === activeSheet)?.sheetId;
      await client.batchUpdate(id, [{
        repeatCell: {
          range: { sheetId, ...a1ToGrid(cmd.range) },
          cell: { userEnteredFormat: { textFormat: { bold: true } } },
          fields: 'userEnteredFormat.textFormat.bold',
        },
      }]);
      return `Жирный шрифт: ${cmd.range}`;
    }
    case 'addSheet': {
      await client.batchUpdate(id, [{ addSheet: { properties: { title: cmd.title } } }]);
      activeSheet = cmd.title;
      $('active').textContent = activeSheet;
      return `Создан лист «${cmd.title}»`;
    }
    case 'switchSheet': {
      const found = (await client.sheets(id)).find((s) => s.title.toLowerCase() === cmd.title.toLowerCase());
      if (!found) throw new Error(`Лист «${cmd.title}» не найден`);
      activeSheet = found.title;
      $('active').textContent = activeSheet;
      return `Активный лист: ${activeSheet}`;
    }
    case 'undo': {
      const prev = undoStack.pop();
      if (!prev) throw new Error('Нечего отменять');
      await client.clear(prev.id, prev.sheet, prev.range);
      if (prev.values.length) await client.setValues(prev.id, prev.sheet, prev.range, prev.values);
      return `Отменено: ${prev.range}`;
    }
    default:
      throw new Error(`Не понял команду: «${cmd.text}»`);
  }
}

async function handle(text) {
  log('say', `🗣 ${text}`);
  try {
    const cmd = parseCommand(text);
    if (!cmd) return;
    const msg = await execute(cmd);
    log('ok', msg);
    say(cmd.type === 'read' || (cmd.type === 'aggregate' && !cmd.target) ? msg : 'Готово');
  } catch (e) {
    log('err', e.message);
    say('Ошибка');
  }
}

function setupSpeech() {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) {
    $('mic').disabled = true;
    $('status').textContent = 'Браузер не поддерживает распознавание речи (нужен Chrome/Edge)';
    return;
  }
  const rec = new SR();
  rec.lang = 'ru-RU';
  rec.continuous = true;
  let on = false;
  rec.onresult = (e) => {
    for (let i = e.resultIndex; i < e.results.length; i++) {
      if (e.results[i].isFinal) handle(e.results[i][0].transcript);
    }
  };
  rec.onerror = (e) => log('err', `Микрофон: ${e.error}`);
  rec.onend = () => { if (on) rec.start(); }; // Chrome сам обрывает долгие сессии
  $('mic').onclick = () => {
    on = !on;
    $('mic').classList.toggle('on', on);
    $('mic').textContent = on ? '⏹ Остановить' : '🎤 Говорить';
    on ? rec.start() : rec.stop();
  };
}

$('clientId').value = store.get('clientId');
$('sheet').value = store.get('sheet');
$('sheet').onchange = () => store.set('sheet', $('sheet').value);
$('signin').onclick = signIn;
$('typed').onsubmit = (e) => {
  e.preventDefault();
  const t = $('typedText').value;
  $('typedText').value = '';
  handle(t);
};
setupSpeech();
