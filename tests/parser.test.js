import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCommand, normalizeRef, a1ToGrid } from '../src/parser.js';

test('normalizeRef понимает русские названия столбцов', () => {
  assert.equal(normalizeRef('бэ 3'), 'B3');
  assert.equal(normalizeRef('b3'), 'B3');
  assert.equal(normalizeRef('цэ12'), 'C12');
  assert.equal(normalizeRef('яя3'), null);
});

test('запись значения: три формулировки', () => {
  const want = { type: 'write', cell: 'B3', value: '500' };
  assert.deepEqual(parseCommand('Запиши 500 в ячейку B3'), want);
  assert.deepEqual(parseCommand('в бэ 3 запиши 500'), want);
  assert.deepEqual(parseCommand('запиши в ячейку B3 500'), want);
});

test('значение сохраняет регистр', () => {
  assert.equal(parseCommand('Запиши Иван Петров в A1').value, 'Иван Петров');
});

test('чтение ячейки и диапазона', () => {
  assert.deepEqual(parseCommand('прочитай ячейку B3'), { type: 'read', range: 'B3' });
  assert.deepEqual(parseCommand('покажи A1 до C5'), { type: 'read', range: 'A1:C5' });
});

test('добавление строки', () => {
  assert.deepEqual(parseCommand('добавь строку: Иван, 25, Москва'), {
    type: 'append', row: ['Иван', '25', 'Москва'],
  });
});

test('агрегаты с целевой ячейкой и без', () => {
  assert.deepEqual(parseCommand('сумма A1 до A10 в ячейку C1'), {
    type: 'aggregate', fn: 'SUM', range: 'A1:A10', target: 'C1',
  });
  assert.deepEqual(parseCommand('среднее A1 A10'), {
    type: 'aggregate', fn: 'AVERAGE', range: 'A1:A10', target: null,
  });
});

test('очистка, форматирование, листы, отмена', () => {
  assert.deepEqual(parseCommand('очисти A1 до C5'), { type: 'clear', range: 'A1:C5' });
  assert.deepEqual(parseCommand('сделай жирным A1 до C1'), { type: 'bold', range: 'A1:C1' });
  assert.deepEqual(parseCommand('новый лист Расходы'), { type: 'addSheet', title: 'Расходы' });
  assert.deepEqual(parseCommand('перейди на лист Расходы'), { type: 'switchSheet', title: 'Расходы' });
  assert.deepEqual(parseCommand('отмени'), { type: 'undo' });
});

test('непонятное -> unknown, пустое -> null', () => {
  assert.equal(parseCommand('какая сегодня погода').type, 'unknown');
  assert.equal(parseCommand('   '), null);
});

test('a1ToGrid', () => {
  assert.deepEqual(a1ToGrid('A1:C5'), {
    startRowIndex: 0, endRowIndex: 5, startColumnIndex: 0, endColumnIndex: 3,
  });
  assert.deepEqual(a1ToGrid('B3'), {
    startRowIndex: 2, endRowIndex: 3, startColumnIndex: 1, endColumnIndex: 2,
  });
});
