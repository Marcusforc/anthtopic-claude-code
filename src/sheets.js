// Тонкая обёртка над Google Sheets API v4 (REST, Bearer-токен из Google Identity Services).

const BASE = 'https://sheets.googleapis.com/v4/spreadsheets';

export class SheetsClient {
  constructor(getToken) {
    this.getToken = getToken;
  }

  async req(path, init = {}) {
    const res = await fetch(BASE + path, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.getToken()}`,
        'Content-Type': 'application/json',
      },
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error?.message ?? `HTTP ${res.status}`);
    return data;
  }

  range(sheet, a1) {
    return encodeURIComponent(`'${sheet.replace(/'/g, "''")}'!${a1}`);
  }

  async getValues(id, sheet, a1, render = 'FORMATTED_VALUE') {
    const d = await this.req(`/${id}/values/${this.range(sheet, a1)}?valueRenderOption=${render}`);
    return d.values ?? [];
  }

  setValues(id, sheet, a1, values) {
    return this.req(`/${id}/values/${this.range(sheet, a1)}?valueInputOption=USER_ENTERED`, {
      method: 'PUT',
      body: JSON.stringify({ values }),
    });
  }

  append(id, sheet, values) {
    return this.req(
      `/${id}/values/${this.range(sheet, 'A1')}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
      { method: 'POST', body: JSON.stringify({ values }) },
    );
  }

  clear(id, sheet, a1) {
    return this.req(`/${id}/values/${this.range(sheet, a1)}:clear`, { method: 'POST', body: '{}' });
  }

  batchUpdate(id, requests) {
    return this.req(`/${id}:batchUpdate`, { method: 'POST', body: JSON.stringify({ requests }) });
  }

  async sheets(id) {
    const d = await this.req(`/${id}?fields=sheets.properties(sheetId,title)`);
    return d.sheets.map((s) => s.properties);
  }
}
