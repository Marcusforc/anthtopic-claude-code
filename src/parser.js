// Разбор голосовых команд на русском в структурированные действия.
// Модуль чистый (без DOM и сети), поэтому его можно тестировать в Node.

const CYR_LETTERS = {
  а: 'A', эй: 'A',
  б: 'B', бэ: 'B', би: 'B',
  с: 'C', ц: 'C', цэ: 'C', си: 'C',
  д: 'D', дэ: 'D', ди: 'D',
  е: 'E', и: 'E',
  ф: 'F', эф: 'F',
  г: 'G', же: 'G', джи: 'G',
  х: 'H', ха: 'H', аш: 'H',
};

const W = '[а-яё]*';
const REF = '[a-zа-яё]{1,3}\\s*\\d{1,5}';
const CELL_WORD = `(?:ячейк${W}\\s+)?`;

const AGG = { сумм: 'SUM', средн: 'AVERAGE', максим: 'MAX', миним: 'MIN', количеств: 'COUNT' };

export function colToken(token) {
  const t = token.toLowerCase();
  if (/^[a-z]{1,3}$/.test(t)) return t.toUpperCase();
  return CYR_LETTERS[t] ?? null;
}

// "бэ 3" / "B3" / "б3" -> "B3"; неизвестное имя столбца -> null
export function normalizeRef(raw) {
  const m = raw.trim().match(/^([a-zа-яё]{1,3})\s*(\d{1,5})$/i);
  if (!m) return null;
  const col = colToken(m[1]);
  return col ? `${col}${Number(m[2])}` : null;
}

export function findRefs(text) {
  const re = /(?<![a-zа-яё])([a-zа-яё]{1,3})\s*(\d{1,5})(?!\d)/gi;
  return [...text.matchAll(re)].map((m) => normalizeRef(m[0])).filter(Boolean);
}

export function colToIndex(col) {
  return [...col].reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0) - 1;
}

// "B3" | "A1:C5" -> GridRange без sheetId (индексы с нуля, конец не включается)
export function a1ToGrid(a1) {
  const [from, to = from] = a1.split(':');
  const p = (r) => {
    const m = r.match(/^([A-Z]+)(\d+)$/);
    return { col: colToIndex(m[1]), row: Number(m[2]) - 1 };
  };
  const s = p(from);
  const e = p(to);
  return {
    startRowIndex: Math.min(s.row, e.row),
    endRowIndex: Math.max(s.row, e.row) + 1,
    startColumnIndex: Math.min(s.col, e.col),
    endColumnIndex: Math.max(s.col, e.col) + 1,
  };
}

function rangeFrom(text) {
  const refs = findRefs(text);
  if (refs.length === 0) return null;
  return refs.length === 1 ? refs[0] : `${refs[0]}:${refs[1]}`;
}

export function parseCommand(input) {
  const text = input.trim().replace(/[.!?]+$/, '').trim();
  if (!text) return null;
  let m;

  if (/^(отмени|отмена|верни)/i.test(text)) return { type: 'undo' };

  if ((m = text.match(new RegExp(`^(?:новый|создай|добавь)\\s+лист\\s+(.+)$`, 'i')))) {
    return { type: 'addSheet', title: m[1].trim() };
  }
  if ((m = text.match(new RegExp(`^(?:перейди|открой|переключись)\\s+(?:на\\s+)?лист\\s+(.+)$`, 'i')))) {
    return { type: 'switchSheet', title: m[1].trim() };
  }

  if ((m = text.match(new RegExp(`^(?:добавь|добавить)\\s+(?:строку|запись)\\s*:?\\s*(.+)$`, 'i')))) {
    const row = m[1].split(/\s*[,;]\s*/).map((v) => v.trim()).filter((v) => v !== '');
    return row.length ? { type: 'append', row } : null;
  }

  if (/^(?:очисти|очистить|сотри|стереть|удали содержимое)/i.test(text)) {
    const range = rangeFrom(text);
    return range ? { type: 'clear', range } : { type: 'unknown', text };
  }

  if (/^(?:прочитай|прочти|покажи|что в)/i.test(text)) {
    const range = rangeFrom(text);
    return range ? { type: 'read', range } : { type: 'unknown', text };
  }

  if (/жирн|выдели/i.test(text)) {
    const range = rangeFrom(text);
    return range ? { type: 'bold', range } : { type: 'unknown', text };
  }

  const aggKey = Object.keys(AGG).find((k) => new RegExp(`^(?:посчитай|вычисли|найди)?\\s*${k}`, 'i').test(text));
  if (aggKey) {
    const t = text.match(new RegExp(`^(.*?)\\s+в\\s+${CELL_WORD}(${REF})$`, 'i'));
    const refs = findRefs(t ? t[1] : text);
    if (refs.length < 2) return { type: 'unknown', text };
    return {
      type: 'aggregate',
      fn: AGG[aggKey],
      range: `${refs[0]}:${refs[1]}`,
      target: t ? normalizeRef(t[2]) : null,
    };
  }

  const verb = '(?:запиши|введи|впиши|поставь)';
  const write = (ref, value) => {
    const cell = normalizeRef(ref);
    return cell && value.trim() ? { type: 'write', cell, value: value.trim() } : null;
  };
  if ((m = text.match(new RegExp(`^${verb}\\s+(.+?)\\s+(?:в|на)\\s+${CELL_WORD}(${REF})$`, 'i')))) {
    return write(m[2], m[1]) ?? { type: 'unknown', text };
  }
  if ((m = text.match(new RegExp(`^(?:в\\s+)?${CELL_WORD}(${REF})\\s+(?:${verb}|равно|=)\\s*(.+)$`, 'i')))) {
    return write(m[1], m[2]) ?? { type: 'unknown', text };
  }
  if ((m = text.match(new RegExp(`^${verb}\\s+(?:в\\s+)?${CELL_WORD}(${REF})\\s+(.+)$`, 'i')))) {
    return write(m[1], m[2]) ?? { type: 'unknown', text };
  }

  return { type: 'unknown', text };
}
