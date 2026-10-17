/* Tiffin desktop admin — a dependency-free SPA over the host's /api (PRD
   §13.4). Scanning is intentionally absent (native app only). Served by the
   embedded shelf server from the same origin, so fetch('/api/...') needs no
   CORS handling. Hash routing means the server only ever serves index.html. */

'use strict';

// --- tiny DOM helper --------------------------------------------------------
function h(tag, props, ...kids) {
  const el = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (k === 'class') el.className = v;
      else if (k === 'html') el.innerHTML = v;
      else if (k === 'text') el.textContent = v;
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (v === true) el.setAttribute(k, '');
      else if (v !== false && v != null) el.setAttribute(k, v);
    }
  }
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    el.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return el;
}
const $ = (sel, root = document) => root.querySelector(sel);

// --- i18n -------------------------------------------------------------------
// English is the source of truth and the fallback: a missing key in hi/mr
// surfaces as English rather than a blank string or a raw key name (Postel's
// Law — CLAUDE.md §13, PRD i18n plan §15.4). Locale is stored the same way
// everything else this SPA remembers is stored — localStorage, same-origin,
// per-device — not a server session, since this static bundle has no
// server-side rendering to hook into.
const i18n = {
  locale: localStorage.getItem('tiffin_locale') || 'en',
  cache: {},
  dict: {},

  async load(locale) {
    if (this.cache[locale]) return this.cache[locale];
    const res = await fetch(`i18n/${locale}.json`);
    const json = await res.json();
    this.cache[locale] = json;
    return json;
  },

  async init() {
    await this.load('en'); // always available as the fallback
    this.dict = await this.load(this.locale).catch(() => this.cache.en);
  },

  async setLocale(locale) {
    this.locale = locale;
    localStorage.setItem('tiffin_locale', locale);
    this.dict = await this.load(locale).catch(() => this.cache.en);
    render();
  },

  _get(dict, path) {
    return path.split('.').reduce((o, k) => (o && o[k] !== undefined ? o[k] : undefined), dict);
  },

  t(key, vars) {
    let val = this._get(this.dict, key);
    if (val === undefined) val = this._get(this.cache.en, key);
    if (val === undefined) return key;
    if (Array.isArray(val)) val = val[Math.floor(Math.random() * val.length)];
    if (vars) for (const [k, v] of Object.entries(vars)) val = val.replaceAll(`{${k}}`, v);
    return val;
  },

  // A list-valued key (e.g. weekday abbreviations), with the same
  // missing-key-falls-back-to-English rule as t().
  tList(key) {
    const val = this._get(this.dict, key) ?? this._get(this.cache.en, key);
    return Array.isArray(val) ? val : [];
  },
};
const t = (key, vars) => i18n.t(key, vars);

const LOCALES = [
  { code: 'en', native: 'English' },
  { code: 'hi', native: 'हिन्दी' },
  { code: 'mr', native: 'मराठी' },
];

// --- api client -----------------------------------------------------------
const api = {
  get token() { return localStorage.getItem('tiffin_token'); },
  set token(v) { v ? localStorage.setItem('tiffin_token', v) : localStorage.removeItem('tiffin_token'); },

  async req(method, path, body) {
    let res;
    try {
      res = await fetch('/api' + path, {
        method,
        headers: {
          'content-type': 'application/json',
          ...(this.token ? { authorization: 'Bearer ' + this.token } : {}),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch (e) {
      throw { code: 'network', message: t('common.networkError') };
    }
    const text = await res.text();
    const data = text ? JSON.parse(text) : null;
    if (!res.ok) {
      if (res.status === 401) { api.token = null; location.hash = '#/login'; }
      throw { code: (data && data.error) || 'error', message: (data && data.message) || t('common.requestFailed', { status: res.status }) };
    }
    return data;
  },
  get(p) { return this.req('GET', p); },
  post(p, b) { return this.req('POST', p, b === undefined ? null : b); },
  patch(p, b) { return this.req('PATCH', p, b); },
  del(p) { return this.req('DELETE', p); },
};

// --- feedback -----------------------------------------------------------
let toastTimer;
function toast(msg, ok = true, ms) {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'toast' + (ok ? '' : ' bad');
  t.hidden = false;
  clearTimeout(toastTimer);
  if (ms !== 0) toastTimer = setTimeout(() => (t.hidden = true), ms || (ok ? 3000 : 6000));
}

// Runs fn with visible feedback the whole way: an immediate "Working…" line,
// then a success line, or on failure the error's message + code — never a
// silent no-op.
async function guard(fn, okMsg) {
  toast(t('common.workingEllipsis'), true, 0);
  try {
    const r = await fn();
    toast(okMsg || t('common.done'));
    return r ?? true;
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    const code = e && e.code ? `  [${e.code}]` : '';
    toast(msg + code, false);
    return false;
  }
}

// Empty-state block — a line of personality instead of a blank table.
function emptyState(key, title, actionLabel, onAction) {
  return h('div', { class: 'card', style: 'text-align:center;padding:40px' },
    h('div', { style: 'font-size:32px' }, '―'),
    h('h2', {}, title),
    h('div', { class: 'muted' }, t(`quips.${key}`) === `quips.${key}` ? t('common.nothingHereYet') : t(`quips.${key}`)),
    (actionLabel && onAction)
      ? h('div', { style: 'margin-top:16px' }, h('button', { class: 'primary', onclick: onAction }, actionLabel))
      : null);
}

function modal(title, bodyNode, { okLabel, onOk } = {}) {
  return new Promise((resolve) => {
    const close = (val) => { back.remove(); resolve(val); };
    const okBtn = h('button', { class: 'primary', onclick: async () => {
      if (onOk) { const r = await onOk(); if (r === false) return; }
      close(true);
    } }, okLabel || t('common.save'));
    const back = h('div', { class: 'modal-back', onclick: (e) => { if (e.target === back) close(false); } },
      h('div', { class: 'modal' },
        h('h2', { text: title }),
        bodyNode,
        h('div', { class: 'actions' },
          h('button', { class: 'ghost', onclick: () => close(false) }, t('common.cancel')),
          okBtn)));
    document.body.append(back);
  });
}

// --- small shared state (prices, category/ingredient lists) ---------------
const store = {
  settings: null, categories: null, ingredients: null,
  async ensureSettings() { return this.settings ??= await api.get('/settings'); },
  async ensureCategories() { return this.categories ??= await api.get('/menu-categories'); },
  async ensureIngredients() { return this.ingredients ??= await api.get('/ingredients'); },
  bust() { this.settings = this.categories = this.ingredients = null; },
};

// Local calendar date (not UTC) — `toISOString` would roll the day over for
// users east/west of UTC. Menu entry dates from the API are already local
// `yyyy-mm-dd`, so the grid must compare against a local "today" too.
const ymd = (d) => {
  const local = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 10);
};
// Locale-aware formatting (CLAUDE.md §13) — `undefined` as the locale arg
// tells `Intl` to use the browser's own locale, which already reflects
// whatever language the operator's OS/browser is set to for number/date
// conventions, independent of which language this admin panel's UI chrome
// is currently showing.
const fmtDate = (s) => new Date(s).toLocaleString();
const fmtDay = (s) => new Date(s).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });

// --- views --------------------------------------------------------------
const views = {};

views.login = async () => {
  const branding = await api.get('/settings/branding').catch(() => ({ appName: 'Tiffin' }));
  const u = h('input', { autofocus: true });
  const p = h('input', { type: 'password' });
  const err = h('div', { class: 'muted', style: 'color:var(--reject)' });
  const btn = h('button', { class: 'primary', onclick: () => submit() }, t('login.signIn'));
  let busy = false;
  const submit = async () => {
    if (busy) return;
    err.textContent = '';
    busy = true;
    btn.disabled = true;
    btn.textContent = t('login.signingIn');
    try {
      const s = await api.post('/auth/login', { username: u.value.trim(), password: p.value });
      if (s.role !== 'admin' && s.role !== 'counter') {
        err.textContent = t('login.roleDenied');
        return;
      }
      api.token = s.token;
      localStorage.setItem('tiffin_role', s.role);
      localStorage.setItem('tiffin_user', s.username);
      location.hash = '#/members';
    } catch (e) {
      err.textContent = e.message;
    } finally {
      busy = false;
      btn.disabled = false;
      btn.textContent = t('login.signIn');
    }
  };
  for (const el of [u, p]) {
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
  }
  return h('div', { class: 'login-wrap' },
    h('div', { class: 'card login-card' },
      h('h1', { text: branding.appName }),
      h('div', { class: 'muted' }, t('login.subtitle')),
      h('label', {}, t('login.username')), u,
      h('label', {}, t('login.password')), p,
      err,
      h('div', { style: 'margin-top:16px' }, btn),
      h('div', { style: 'margin-top:16px;text-align:center' }, localeSwitcher())));
};

// generic resource table with add/edit/delete via a field spec
function crudView({ title, path, columns, fields, toBody, canDelete = true, extra, emptyKey }) {
  return async () => {
    const rows = await api.get(path);
    const openForm = (row) => {
      const inputs = {};
      const body = h('div', {});
      for (const f of fields) {
        let input;
        if (f.type === 'select') {
          input = h('select', {}, ...f.options.map((o) =>
            h('option', { value: o.value, ...(String(row?.[f.key] ?? f.default) === String(o.value) ? { selected: true } : {}) }, o.label)));
        } else if (f.type === 'textarea') {
          input = h('textarea', { rows: 3 }); input.value = row?.[f.key] ?? '';
        } else {
          input = h('input', { type: f.type || 'text' });
          input.value = row?.[f.key] ?? (f.default ?? '');
        }
        inputs[f.key] = input;
        body.append(h('label', {}, f.label), input);
      }
      modal(row ? t('crud.editTitle', { title }) : t('crud.newTitle', { title }), body, {
        onOk: async () => {
          const payload = toBody(inputs, row);
          const ok = await guard(
            () => row ? api.patch(`${path}/${row.id}`, payload) : api.post(path, payload),
            t('common.done'));
          if (ok) render();
          return ok;
        },
      });
    };
    return h('div', {},
      h('div', { class: 'row between' }, h('h1', { text: title }),
        h('button', { class: 'primary', onclick: () => openForm(null) }, t('crud.newButton'))),
      extra ? extra(render) : null,
      rows.length === 0
        ? emptyState(emptyKey || 'members', t('crud.emptyTitle', { title }), t('crud.newTitleButton', { title }), () => openForm(null))
        : h('table', {},
        h('thead', {}, h('tr', {}, ...columns.map((c) => h('th', { text: c.label })), h('th', { text: '' }))),
        h('tbody', {}, ...rows.map((r) => h('tr', {},
          ...columns.map((c) => h('td', {}, c.render ? c.render(r) : String(r[c.key] ?? ''))),
          h('td', {},
            h('button', { class: 'ghost', onclick: () => openForm(r) }, t('common.edit')),
            canDelete ? h('button', { class: 'ghost danger', onclick: async () => {
              if (await guard(() => api.del(`${path}/${r.id}`), t('common.done'))) render();
            } }, t('common.del')) : null))))));
  };
}

// members ------------------------------------------------------------------
views.members = async () => {
  const [members, settings] = await Promise.all([
    api.get('/members'), store.ensureSettings(),
  ]);

  const openForm = (m) => {
    const type = h('select', {}, h('option', { value: 'student' }, t('members.typeStudent')), h('option', { value: 'staff' }, t('members.typeStaff')));
    if (m) { type.value = m.type; type.disabled = true; }
    const name = h('input', {}); name.value = m?.name ?? '';
    const className = h('input', {}); className.value = m?.className ?? '';
    const roll = h('input', {}); roll.value = m?.rollNumber ?? '';
    const staffId = h('input', {}); staffId.value = m?.staffId ?? '';
    const grace = h('input', { type: 'number' }); grace.value = m?.graceAllowanceOverride ?? '';
    const status = h('select', {}, h('option', { value: 'active' }, t('members.statusActive')), h('option', { value: 'inactive' }, t('members.statusInactive')));
    if (m) status.value = m.status;
    const studentFields = h('div', {}, h('label', {}, t('members.fieldClass')), className, h('label', {}, t('members.fieldRoll')), roll);
    const staffFields = h('div', {}, h('label', {}, t('members.fieldStaffId')), staffId);
    const sync = () => { const s = type.value === 'student'; studentFields.hidden = !s; staffFields.hidden = s; };
    type.addEventListener('change', sync);
    const body = h('div', {}, h('label', {}, t('members.fieldType')), type, h('label', {}, t('members.fieldName')), name,
      studentFields, staffFields,
      h('label', {}, t('members.fieldGraceOverride')), grace,
      ...(m ? [h('label', {}, t('members.fieldStatus')), status] : []));
    sync();
    modal(m ? t('members.formEdit') : t('members.formNew'), body, {
      onOk: async () => {
        const isStudent = type.value === 'student';
        const payload = {
          name: name.value.trim(),
          className: isStudent ? (className.value.trim() || null) : null,
          rollNumber: isStudent ? (roll.value.trim() || null) : null,
          staffId: !isStudent ? (staffId.value.trim() || null) : null,
          graceAllowanceOverride: grace.value === '' ? null : Number(grace.value),
        };
        let ok;
        if (m) ok = await guard(() => api.patch(`/members/${m.id}`, { ...payload, status: status.value }), t('members.updatedToast'));
        else ok = await guard(() => api.post('/members', { type: type.value, ...payload }), t('members.createdToast'));
        if (ok) render();
        return ok;
      },
    });
  };

  const credit = (m) => {
    const l = h('input', { type: 'number', value: '0' });
    const b = h('input', { type: 'number', value: '0' });
    const br = h('input', { type: 'number', value: '0' });
    modal(t('members.creditTitle', { name: m.name }), h('div', {}, h('label', {}, t('members.creditLunch')), l, h('label', {}, t('members.creditBreakfast')), b, h('label', {}, t('members.creditBrunch')), br), {
      okLabel: t('members.creditAddUnits'),
      onOk: async () => {
        const ok = await guard(() => api.post(`/members/${m.id}/credit`, {
          lunch: Number(l.value) || 0, breakfast: Number(b.value) || 0, brunch: Number(br.value) || 0,
        }), t('members.creditToast'));
        if (ok) render();
        return ok;
      },
    });
  };

  const showQr = async (m) => {
    const res = await fetch(`/api/members/${m.id}/qr`, { headers: { authorization: 'Bearer ' + api.token } });
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    modal(m.name, h('div', { style: 'text-align:center' },
      h('img', { src: url, style: 'width:280px;height:280px;image-rendering:pixelated' }),
      h('div', { class: 'muted' }, m.qrCodeId)), { okLabel: t('common.close'), onOk: () => { URL.revokeObjectURL(url); } });
  };

  const header = h('div', { class: 'row between' },
    h('h1', {}, members.length ? t('members.headerCount', { count: members.length }) : t('members.header')),
    h('button', { class: 'primary', onclick: () => openForm(null) }, t('members.newButton')));

  if (!members.length) {
    return h('div', {}, header,
      emptyState('members', t('members.emptyTitle'), t('members.newButton'), () => openForm(null)));
  }

  return h('div', {}, header,
    h('table', {},
      h('thead', {}, h('tr', {}, ...[t('members.colName'), t('members.colType'), t('members.colDetail'), t('members.colLunch'), t('members.colBfast'), t('members.colBrunch'), t('members.colStatus'), ''].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...members.map((m) => h('tr', {},
        h('td', { text: m.name }),
        h('td', { text: m.type }),
        h('td', { text: m.type === 'student' ? `${m.className || '—'} / ${m.rollNumber || '—'}` : (m.staffId || '—') }),
        h('td', { text: m.balances.lunch }),
        h('td', { text: m.balances.breakfast }),
        h('td', { text: m.balances.brunch }),
        h('td', {}, m.status === 'active' ? h('span', { class: 'pill ok' }, t('members.statusActive')) : h('span', { class: 'pill' }, t('members.statusInactive'))),
        h('td', {},
          h('button', { class: 'ghost', onclick: () => openForm(m) }, t('members.editBtn')),
          h('button', { class: 'ghost', onclick: () => credit(m) }, t('members.creditBtn')),
          h('button', { class: 'ghost', onclick: () => showQr(m) }, t('members.qrBtn')))))),
    h('div', { class: 'muted', style: 'margin-top:8px' }, t('members.unitPricesLine', { lunch: settings.unitPrices.lunch, breakfast: settings.unitPrices.breakfast, brunch: settings.unitPrices.brunch })));
};

// top-ups ----------------------------------------------------------------
views.topups = async () => {
  const [members, settings, topups] = await Promise.all([
    api.get('/members?status=active'), store.ensureSettings(), api.get('/topups'),
  ]);
  const memberById = Object.fromEntries(members.map((m) => [m.id, m]));
  if (!members.length) return h('div', {}, h('h1', {}, t('topups.header')),
    emptyState('members', t('topups.emptyTitle'), '', null));


  const open = () => {
    const sel = h('select', {}, ...members.map((m) => h('option', { value: m.id }, `${m.name} (${m.type})`)));
    const l = h('input', { type: 'number', value: '0' });
    const b = h('input', { type: 'number', value: '0' });
    const br = h('input', { type: 'number', value: '0' });
    const method = h('select', {}, h('option', { value: 'cash' }, t('topups.paymentCash')), h('option', { value: 'upi' }, t('topups.paymentUpi')));
    const total = h('b', { text: 'Rs. 0.00' });
    const recalc = () => {
      const p = settings.unitPrices;
      const amt = (Number(l.value) || 0) * p.lunch + (Number(b.value) || 0) * p.breakfast + (Number(br.value) || 0) * p.brunch;
      total.textContent = 'Rs. ' + amt.toFixed(2);
    };
    [l, b, br].forEach((i) => i.addEventListener('input', recalc));
    const body = h('div', {}, h('label', {}, t('topups.fieldMember')), sel,
      h('label', {}, t('topups.fieldLunchUnits')), l, h('label', {}, t('topups.fieldBreakfastUnits')), b, h('label', {}, t('topups.fieldBrunchUnits')), br,
      h('label', {}, t('topups.fieldPayment')), method,
      h('div', { class: 'card', style: 'margin-top:12px' }, h('div', { class: 'row between' }, h('span', {}, t('topups.totalLabel')), total)));
    modal(t('topups.modalTitle'), body, {
      okLabel: t('topups.chargeBtn'),
      onOk: async () => {
        if ((Number(l.value) || 0) + (Number(b.value) || 0) + (Number(br.value) || 0) === 0) {
          toast(t('topups.addAtLeastOne'), false); return false;
        }
        const created = await guard(() => api.post('/topups', {
          memberId: Number(sel.value), lunchUnits: Number(l.value) || 0,
          breakfastUnits: Number(b.value) || 0, brunchUnits: Number(br.value) || 0,
          paymentMethod: method.value,
        }), t('topups.creditedToast'));
        if (created) { render(); showBill(created); }
        return !!created;
      },
    });
  };

  const showBill = async (top) => {
    const kids = [h('div', {}, t('topups.amountLine', { amount: top.amount.toFixed(2), method: top.paymentMethod.toUpperCase() })),
      h('div', {}, t('topups.statusLine', { status: top.paymentStatus }))];
    if (top.paymentMethod === 'upi' && top.hasUpiQr) {
      const res = await fetch(`/api/topups/${top.id}/upi-qr`, { headers: { authorization: 'Bearer ' + api.token } });
      const url = URL.createObjectURL(await res.blob());
      kids.push(h('div', { class: 'muted', style: 'margin-top:12px' }, t('topups.scanQrPrompt')),
        h('img', { src: url, style: 'width:220px;height:220px' }));
    }
    if (top.hasBill) kids.push(h('div', { style: 'margin-top:12px' },
      h('a', { href: `/api/topups/${top.id}/bill?token=${api.token}`, target: '_blank' }, t('topups.openBillPdf'))));
    modal(t('topups.billTitle', { id: top.id }), h('div', {}, ...kids), { okLabel: t('topups.doneBtn'), onOk: () => {} });
  };

  return h('div', {},
    h('div', { class: 'row between' }, h('h1', {}, t('topups.header')),
      h('button', { class: 'primary', onclick: open }, t('topups.newButton'))),
    h('table', {},
      h('thead', {}, h('tr', {}, ...[t('topups.colId'), t('topups.colMember'), t('topups.colUnits'), t('topups.colAmount'), t('topups.colMethod'), t('topups.colStatus'), t('topups.colWhen'), ''].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...topups.map((top) => h('tr', {},
        h('td', { text: top.id }),
        h('td', { text: memberById[top.memberId]?.name ?? top.memberId }),
        h('td', { text: `${top.lunchUnits}/${top.breakfastUnits}/${top.brunchUnits}` }),
        h('td', { text: 'Rs. ' + top.amount.toFixed(2) }),
        h('td', { text: top.paymentMethod }),
        h('td', {}, top.paymentStatus === 'confirmed' ? h('span', { class: 'pill ok' }, t('topups.statusConfirmed')) : h('span', { class: 'pill warn' }, t('topups.statusPending'))),
        h('td', { text: fmtDate(top.createdAt) }),
        h('td', {},
          top.paymentStatus === 'pending' ? h('button', { class: 'ghost', onclick: async () => {
            if (await guard(() => api.post(`/topups/${top.id}/confirm-payment`), t('topups.confirmedToast'))) render();
          } }, t('topups.markReceived')) : null,
          top.hasBill ? h('a', { href: `/api/topups/${top.id}/bill?token=${api.token}`, target: '_blank' }, h('button', { class: 'ghost' }, t('topups.billBtn'))) : null))))));
};

// scan log -------------------------------------------------------------
views.scans = async () => {
  const scans = await api.get('/scans?limit=300');
  if (!scans.length) return h('div', {},
    h('h1', {}, t('scans.header')),
    emptyState('scans', t('scans.emptyTitle'), null, null));

  return h('div', {},
    h('h1', {}, t('scans.header')),
    h('table', {},
      h('thead', {}, h('tr', {}, ...[t('scans.colMember'), t('scans.colMeal'), t('scans.colWhen'), t('scans.colFlags'), ''].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...scans.map((s) => h('tr', {},
        h('td', { text: s.memberName }),
        h('td', { text: s.mealType }),
        h('td', { text: fmtDate(s.scannedAt) }),
        h('td', {}, s.reversed ? h('span', { class: 'pill bad' }, t('scans.flagReversed')) : (s.viaGrace ? h('span', { class: 'pill warn' }, t('scans.flagGrace')) : '')),
        h('td', {}, (s.result === 'accepted' && !s.reversed) ? h('button', { class: 'ghost', onclick: async () => {
          const r = await guard(() => api.post('/scan/reverse', { scanId: s.id }));
          if (r && r.success) { toast(r.message); render(); }
          else if (r) toast(r.message, false);
        } }, t('scans.reverseBtn')) : ''))))));
};

// menu calendar ------------------------------------------------------
// Month grid + day panel, matching the mobile app (lib/ui/admin/menu_screen.dart).
// Selected month/day survive a re-render (they live outside the view fn).
const MEAL_COLOR = { breakfast: 'var(--warn)', lunch: 'var(--accent)', brunch: 'var(--accept)' };
const menuState = {
  month: new Date(new Date().getFullYear(), new Date().getMonth(), 1),
  day: ymd(new Date()),
};

views.menu = async () => {
  const m = menuState.month;
  const monthStart = new Date(m.getFullYear(), m.getMonth(), 1);
  const monthEnd = new Date(m.getFullYear(), m.getMonth() + 1, 0);
  const [entries, cats] = await Promise.all([
    api.get(`/menu?start=${ymd(monthStart)}&end=${ymd(monthEnd)}`), store.ensureCategories(),
  ]);
  const byDay = {};
  for (const e of entries) (byDay[e.date] ??= []).push(e);

  const addEntry = (dateStr) => {
    const date = h('input', { type: 'date', value: dateStr });
    const meal = h('select', {}, ...['breakfast', 'lunch', 'brunch'].map((x) => h('option', { value: x }, t(`common.meal${x[0].toUpperCase()}${x.slice(1)}`))));
    const catBox = h('div', { class: 'row' }, ...cats.map((c) => {
      const cb = h('input', { type: 'checkbox', value: c.name, style: 'width:auto' });
      return h('label', { style: 'display:flex;gap:4px;align-items:center;text-transform:none' }, cb, c.name);
    }));
    const items = h('input', { placeholder: t('menu.itemsPlaceholder') });
    modal(t('menu.addEntryTitle'), h('div', {}, h('label', {}, t('menu.fieldDate')), date, h('label', {}, t('menu.fieldMeal')), meal,
      h('label', {}, t('menu.fieldCategories')), catBox, h('label', {}, t('menu.fieldItems')), items), {
      okLabel: t('menu.addBtn'),
      onOk: async () => {
        const chosen = [...catBox.querySelectorAll('input:checked')].map((i) => i.value);
        const ok = await guard(() => api.post('/menu', {
          date: date.value, mealType: meal.value, categories: chosen,
          items: items.value.split(',').map((s) => s.trim()).filter(Boolean),
        }), t('menu.entryAddedToast'));
        if (ok) { menuState.day = date.value; render(); }
        return ok;
      },
    });
  };
  const stepMonth = (delta) => {
    menuState.month = new Date(m.getFullYear(), m.getMonth() + delta, 1);
    render();
  };

  // grid: Monday-first, leading blanks for the first row
  const leadingBlanks = (monthStart.getDay() + 6) % 7;
  const todayStr = ymd(new Date());
  const cells = [];
  for (let i = 0; i < leadingBlanks; i++) cells.push(h('div', { class: 'cal-cell blank' }));
  for (let d = 1; d <= monthEnd.getDate(); d++) {
    const dateStr = ymd(new Date(m.getFullYear(), m.getMonth(), d));
    const dayEntries = byDay[dateStr] || [];
    const meals = [...new Set(dayEntries.map((e) => e.mealType))];
    const cls = 'cal-cell'
      + (dateStr === menuState.day ? ' selected' : '')
      + (dateStr === todayStr ? ' today' : '');
    cells.push(h('div', { class: cls, onclick: () => { menuState.day = dateStr; render(); } },
      h('div', { class: 'cal-num' }, String(d)),
      h('div', { class: 'cal-dots' }, ...meals.map((mt) =>
        h('span', { class: 'cal-dot', style: `background:${MEAL_COLOR[mt] || 'var(--ink)'}` }))),
      dayEntries.length ? h('div', { class: 'cal-count' }, String(dayEntries.length)) : null));
  }

  const selEntries = (byDay[menuState.day] || []).slice()
    .sort((a, b) => a.mealType.localeCompare(b.mealType));
  const panel = h('div', { class: 'card' },
    h('div', { class: 'row between' },
      h('h3', { style: 'margin:0', text: fmtDay(menuState.day) }),
      h('button', { class: 'primary', onclick: () => addEntry(menuState.day) }, t('menu.addBtnShort'))),
    selEntries.length
      ? h('div', {}, ...selEntries.map((e) => h('div', { class: 'row between', style: 'padding:6px 0;border-top:2px solid var(--surface-muted)' },
          h('div', {},
            h('span', { class: 'cal-dot', style: `background:${MEAL_COLOR[e.mealType] || 'var(--ink)'};margin-right:6px` }),
            h('b', {}, e.mealType + ' '),
            h('span', { class: 'muted' }, e.categories.join(', ')),
            h('div', {}, e.items.join(', '))),
          h('button', { class: 'ghost danger', onclick: async () => {
            if (await guard(() => api.del(`/menu/${e.id}`), t('menu.removedToast'))) render();
          } }, t('common.del')))))
      : h('div', { class: 'muted', style: 'margin-top:8px' }, t('menu.nothingPlanned')));

  return h('div', {},
    h('div', { class: 'row between' },
      h('div', { class: 'row' },
        h('button', { class: 'ghost', onclick: () => stepMonth(-1) }, '‹'),
        h('h1', { style: 'margin:0', text: m.toLocaleDateString(undefined, { month: 'long', year: 'numeric' }) }),
        h('button', { class: 'ghost', onclick: () => stepMonth(1) }, '›')),
      h('button', { class: 'primary', onclick: () => addEntry(menuState.day) }, t('menu.headerAddEntry'))),
    h('div', { class: 'cal-head' }, ...i18n.tList('menu.weekdays').map((w) => h('div', {}, w))),
    h('div', { class: 'cal-grid' }, ...cells),
    panel);
};

views.categories = crudView({
  title: t('categories.title'), path: '/menu-categories', emptyKey: 'categories',
  columns: [{ label: t('crud.colName'), key: 'name' }, { label: t('crud.colDescription'), key: 'description' }],
  fields: [{ key: 'name', label: t('crud.fieldName') }, { key: 'description', label: t('crud.fieldDescription') }],
  toBody: (i) => ({ name: i.name.value.trim(), description: i.description.value.trim() || null }),
});

views.ingredients = crudView({
  title: t('ingredients.title'), path: '/ingredients', emptyKey: 'ingredients',
  columns: [{ label: t('crud.colName'), key: 'name' }, { label: t('crud.colUnit'), key: 'unit' }],
  fields: [{ key: 'name', label: t('crud.fieldName') }, { key: 'unit', label: t('crud.fieldUnit') }],
  toBody: (i) => ({ name: i.name.value.trim(), unit: i.unit.value.trim() }),
});

// recipes -----------------------------------------------------------
views.recipes = async () => {
  const [recipes, ingredients] = await Promise.all([api.get('/recipes'), store.ensureIngredients()]);
  const nameById = Object.fromEntries(ingredients.map((i) => [i.id, i.name]));

  const open = (r) => {
    const dish = h('input', {}); dish.value = r?.dishName ?? '';
    const lines = h('div', {});
    const addLine = (ri) => {
      const sel = h('select', { style: 'width:50%' }, ...ingredients.map((i) => h('option', { value: i.id }, i.name)));
      if (ri) sel.value = ri.ingredientId;
      const note = h('input', { style: 'width:45%', placeholder: t('recipes.quantityPlaceholder') }); note.value = ri?.quantityNote ?? '';
      lines.append(h('div', { class: 'row', style: 'margin-bottom:4px' }, sel, note));
    };
    (r?.ingredients ?? [null]).forEach(addLine);
    modal(r ? t('recipes.formEdit') : t('recipes.formNew'), h('div', {}, h('label', {}, t('recipes.fieldDishName')), dish,
      h('label', {}, t('recipes.fieldIngredients')), lines,
      h('button', { class: 'ghost', onclick: () => addLine(null) }, t('recipes.addIngredientBtn'))), {
      onOk: async () => {
        const rows = [...lines.querySelectorAll('.row')].map((row) => {
          const [sel, note] = row.querySelectorAll('select,input');
          return { ingredientId: Number(sel.value), quantityNote: note.value.trim() };
        }).filter((x) => x.quantityNote);
        const payload = { dishName: dish.value.trim(), ingredients: rows };
        const ok = await guard(() => r ? api.patch(`/recipes/${r.id}`, payload) : api.post('/recipes', payload), t('recipes.savedToast'));
        if (ok) render();
        return ok;
      },
    });
  };
  const header = h('div', { class: 'row between' }, h('h1', {}, t('recipes.header')),
    h('button', { class: 'primary', onclick: () => open(null) }, t('recipes.newButton')));
  if (!recipes.length) {
    return h('div', {}, header,
      emptyState('recipes', t('recipes.emptyTitle'), t('recipes.emptyAction'), () => open(null)));
  }
  return h('div', {}, header,
    h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, t('recipes.colDish')), h('th', {}, t('recipes.colIngredients')), h('th', {}, ''))),
      h('tbody', {}, ...recipes.map((r) => h('tr', {},
        h('td', { text: r.dishName }),
        h('td', { text: r.ingredients.map((x) => nameById[x.ingredientId] || x.ingredientId).join(', ') }),
        h('td', {}, h('button', { class: 'ghost', onclick: () => open(r) }, t('common.edit')),
          h('button', { class: 'ghost danger', onclick: async () => { if (await guard(() => api.del(`/recipes/${r.id}`), t('recipes.deletedToast'))) render(); } }, t('common.del'))))))));
};

// purchase schedule ------------------------------------------------
views.purchase = async () => {
  const [items, ingredients] = await Promise.all([api.get('/purchase-schedule'), store.ensureIngredients()]);
  const generate = () => {
    const s = h('input', { type: 'date', value: ymd(new Date()) });
    const e = h('input', { type: 'date', value: ymd(new Date(Date.now() + 7 * 864e5)) });
    modal(t('purchase.generateModalTitle'), h('div', {}, h('label', {}, t('purchase.fieldFrom')), s, h('label', {}, t('purchase.fieldTo')), e), {
      okLabel: t('purchase.generateOkBtn'),
      onOk: async () => {
        const r = await guard(() => api.post(`/purchase-schedule/generate?start=${s.value}&end=${e.value}`));
        if (r) { toast(t('purchase.addedToast', { count: r.created })); render(); }
        return !!r;
      },
    });
  };
  const addManual = () => {
    const sel = h('select', {}, ...ingredients.map((i) => h('option', { value: i.id }, i.name)));
    const date = h('input', { type: 'date', value: ymd(new Date()) });
    const note = h('input', { placeholder: t('purchase.quantityPlaceholder') });
    modal(t('purchase.addItemModalTitle'), h('div', {}, h('label', {}, t('purchase.fieldIngredient')), sel, h('label', {}, t('menu.fieldDate')), date, h('label', {}, t('purchase.fieldQuantityNote')), note), {
      okLabel: t('menu.addBtn'),
      onOk: async () => {
        const ok = await guard(() => api.post('/purchase-schedule', {
          date: date.value, ingredientId: Number(sel.value), quantityNote: note.value.trim(),
        }), t('purchase.itemAddedToast'));
        if (ok) render();
        return ok;
      },
    });
  };
  const byDay = {};
  for (const it of items) (byDay[it.date] ??= []).push(it);
  if (!items.length) return h('div', {}, h('h1', {}, t('purchase.header')),
    emptyState('purchase', t('purchase.emptyTitle'), t('purchase.emptyAction'), generate));
  return h('div', {},
    h('div', { class: 'row between' }, h('h1', {}, t('purchase.header')),
      h('div', { class: 'row' }, h('button', { onclick: generate }, t('purchase.generateBtn')), h('button', { class: 'primary', onclick: addManual }, t('purchase.addItemBtn')))),
    ...Object.keys(byDay).sort().map((d) => h('div', { class: 'card' },
      h('h3', { text: fmtDay(d) }),
      ...byDay[d].map((it) => {
        const cb = h('input', { type: 'checkbox', style: 'width:auto', ...(it.purchased ? { checked: true } : {}) });
        cb.addEventListener('change', async () => {
          await guard(() => api.patch(`/purchase-schedule/${it.id}`, { purchased: cb.checked }));
          render();
        });
        return h('div', { class: 'row between' },
          h('label', { style: 'display:flex;gap:8px;align-items:center;text-transform:none' }, cb,
            h('span', {}, `${it.ingredientName} — ${it.quantityNote} (${it.ingredientUnit})`),
            h('span', { class: 'muted' }, it.source === 'manual' ? t('purchase.sourceManual') : t('purchase.sourceMenu'))),
          h('button', { class: 'ghost danger', onclick: async () => { if (await guard(() => api.del(`/purchase-schedule/${it.id}`), t('purchase.removedToast'))) render(); } }, t('common.del')));
      }))),
    items.length ? null : h('div', { class: 'muted' }, t('purchase.nothingScheduled')));
};

// expenses --------------------------------------------------------
views.expenses = async () => {
  const [list, summary] = await Promise.all([api.get('/expenses'), api.get('/expenses/summary')]);
  const open = () => {
    const cat = h('input', {}); const desc = h('input', {});
    const amt = h('input', { type: 'number' }); const date = h('input', { type: 'date', value: ymd(new Date()) });
    modal(t('expenses.modalTitle'), h('div', {}, h('label', {}, t('expenses.fieldCategory')), cat, h('label', {}, t('expenses.fieldDescription')), desc,
      h('label', {}, t('expenses.fieldAmount')), amt, h('label', {}, t('expenses.fieldDate')), date), {
      onOk: async () => {
        const ok = await guard(() => api.post('/expenses', {
          category: cat.value.trim(), description: desc.value.trim(), amount: Number(amt.value) || 0, date: date.value,
        }), t('expenses.loggedToast'));
        if (ok) render();
        return ok;
      },
    });
  };
  return h('div', {},
    h('div', { class: 'row between' }, h('h1', {}, t('expenses.header')), h('button', { class: 'primary', onclick: open }, t('expenses.logBtn'))),
    h('div', { class: 'summary' },
      h('div', { class: 'stat' }, h('b', { text: 'Rs. ' + summary.revenue.toFixed(0) }), t('expenses.statRevenue')),
      h('div', { class: 'stat' }, h('b', { text: 'Rs. ' + summary.expenses.toFixed(0) }), t('expenses.statExpenses')),
      h('div', { class: 'stat' }, h('b', { text: 'Rs. ' + summary.profit.toFixed(0) }), t('expenses.statProfit'))),
    list.length === 0 ? emptyState('expenses', t('expenses.emptyTitle'), t('expenses.logBtn'), open) :
    h('table', { style: 'margin-top:16px' }, h('thead', {}, h('tr', {}, ...[t('expenses.colDate'), t('expenses.colCategory'), t('expenses.colDescription'), t('expenses.colAmount')].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...list.map((e) => h('tr', {},
        h('td', { text: new Date(e.date).toLocaleDateString() }),
        h('td', { text: e.category }), h('td', { text: e.description }),
        h('td', { text: 'Rs. ' + e.amount.toFixed(2) }))))));
};

// refunds -------------------------------------------------------
views.refunds = async () => {
  const [list, members] = await Promise.all([api.get('/refunds'), api.get('/members')]);
  const nameById = Object.fromEntries(members.map((m) => [m.id, m.name]));
  const open = () => {
    const sel = h('select', {}, ...members.map((m) => h('option', { value: m.id }, m.name)));
    const l = h('input', { type: 'number' }); const b = h('input', { type: 'number' }); const br = h('input', { type: 'number' });
    const reason = h('input', {});
    const prefill = () => { const m = members.find((x) => x.id === Number(sel.value)); l.value = m.balances.lunch; b.value = m.balances.breakfast; br.value = m.balances.brunch; };
    sel.addEventListener('change', prefill); prefill();
    modal(t('refunds.modalTitle'), h('div', {}, h('label', {}, t('refunds.fieldMember')), sel, h('label', {}, t('refunds.fieldLunch')), l, h('label', {}, t('refunds.fieldBreakfast')), b,
      h('label', {}, t('refunds.fieldBrunch')), br, h('label', {}, t('refunds.fieldReason')), reason), {
      okLabel: t('refunds.processBtn'),
      onOk: async () => {
        const ok = await guard(() => api.post('/refunds', {
          memberId: Number(sel.value), lunchUnits: Number(l.value) || 0, breakfastUnits: Number(b.value) || 0,
          brunchUnits: Number(br.value) || 0, reason: reason.value.trim() || null,
        }), t('refunds.recordedToast'));
        if (ok) render();
        return ok;
      },
    });
  };
  return h('div', {},
    h('div', { class: 'row between' }, h('h1', {}, t('refunds.header')), h('button', { class: 'primary', onclick: open }, t('refunds.newButton'))),
    list.length === 0 ? emptyState('refunds', t('refunds.emptyTitle'), t('refunds.newButton'), open) :
    h('table', {}, h('thead', {}, h('tr', {}, ...[t('refunds.colMember'), t('refunds.colUnits'), t('refunds.colAmount'), t('refunds.colBy'), t('refunds.colReason'), t('refunds.colWhen')].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...list.map((r) => h('tr', {},
        h('td', { text: nameById[r.memberId] ?? r.memberId }),
        h('td', { text: `${r.lunchUnits}/${r.breakfastUnits}/${r.brunchUnits}` }),
        h('td', { text: 'Rs. ' + r.refundAmount.toFixed(2) }),
        h('td', { text: r.processedBy }), h('td', { text: r.reason || '' }),
        h('td', { text: fmtDate(r.createdAt) }))))));
};

// users -------------------------------------------------------
views.users = async () => {
  const users = await api.get('/users');

  const open = (u) => {
    const name = h('input', {}); name.value = u?.username ?? '';
    const pw = h('input', { type: 'password', placeholder: u ? t('users.fieldPasswordBlankHint') : '' });
    const role = h('select', {}, ...['admin', 'counter', 'scanner'].map((r) => h('option', { value: r }, r)));
    if (u) role.value = u.role;
    const status = h('select', {}, h('option', { value: 'active' }, t('members.statusActive')), h('option', { value: 'inactive' }, t('members.statusInactive')));
    if (u) status.value = u.status;
    modal(u ? u.username : t('users.modalNewTitle'), h('div', {}, h('label', {}, t('users.fieldUsername')), name, h('label', {}, t('users.fieldPassword')), pw,
      h('label', {}, t('users.fieldRole')), role, ...(u ? [h('label', {}, t('users.fieldStatus')), status] : [])), {
      onOk: async () => {
        let ok;
        if (u) ok = await guard(() => api.patch(`/users/${u.id}`, { username: name.value.trim() === u.username ? undefined : name.value.trim(), password: pw.value || undefined, role: role.value, status: status.value }), t('users.savedToast'));
        else ok = await guard(() => api.post('/users', { username: name.value.trim(), password: pw.value, role: role.value }), t('users.createdToast'));
        if (ok) render();
        return ok;
      },
    });
  };
  const header = h('div', { class: 'row between' }, h('h1', {}, t('users.header')),
    h('button', { class: 'primary', onclick: () => open(null) }, t('users.newButton')));
  if (!users.length) {
    return h('div', {}, header,
      emptyState('users', t('users.emptyTitle'), t('users.newButton'), () => open(null)));
  }
  return h('div', {}, header,
    h('table', {}, h('thead', {}, h('tr', {}, ...[t('users.colUsername'), t('users.colRole'), t('users.colStatus'), ''].map((x) => h('th', { text: x })))),
      h('tbody', {}, ...users.map((u) => h('tr', {},
        h('td', { text: u.username }), h('td', { text: u.role }), h('td', { text: u.status }),
        h('td', {}, h('button', { class: 'ghost', onclick: () => open(u) }, t('common.edit')),
          h('button', { class: 'ghost danger', onclick: async () => { if (await guard(() => api.del(`/users/${u.id}`), t('users.deletedToast'))) render(); } }, t('common.del'))))))));
};

// settings ---------------------------------------------------
views.settings = async () => {
  const [s, zones] = await Promise.all([api.get('/settings'), api.get('/settings/timezones')]);
  const f = {};
  const field = (key, label, val, type = 'text') => { const i = h('input', { type }); i.value = val; f[key] = i; return h('div', {}, h('label', {}, label), i); };
  const win = {};
  const winRow = (m) => {
    const st = h('input', { value: s.mealWindows[m].start, style: 'width:45%' });
    const en = h('input', { value: s.mealWindows[m].end, style: 'width:45%' });
    win[m] = { st, en };
    return h('div', {}, h('label', {}, m), h('div', { class: 'row' }, st, en));
  };
  // Type-to-filter combobox rather than a 600-option <select>: the browser
  // filters a <datalist> natively. A typo is caught server-side by the tz
  // validator, so a bad value fails loudly instead of being silently kept.
  const tzList = h('datalist', { id: 'tz-options' }, ...zones.map((z) => h('option', { value: z })));
  const tz = h('input', { list: 'tz-options', placeholder: t('settings.tzPlaceholder') });
  tz.value = s.localTimezone;
  const graceOn = h('input', { type: 'checkbox', style: 'width:auto', ...(s.graceAllowanceEnabled ? { checked: true } : {}) });

  const save = async () => {
    const ok = await guard(() => api.patch('/settings', {
      appName: f.appName.value.trim(),
      unitPrices: { lunch: Number(f.lunch.value), breakfast: Number(f.breakfast.value), brunch: Number(f.brunch.value) },
      mealWindows: Object.fromEntries(['breakfast', 'lunch', 'brunch'].map((m) => [m, { start: win[m].st.value.trim(), end: win[m].en.value.trim() }])),
      localTimezone: tz.value,
      graceAllowanceEnabled: graceOn.checked,
      graceAllowanceUnits: Number(f.graceUnits.value),
      reversalWindowMinutes: Number(f.reversal.value),
      prepLeadMinutes: Number(f.prepLead.value),
      purchaseLeadDays: Number(f.purchaseLead.value),
      upiId: f.upiId.value.trim(),
      upiPayeeName: f.upiPayee.value.trim(),
    }), t('settings.savedToast'));
    if (ok) { store.bust(); render(); }
  };

  return h('div', {},
    h('h1', {}, t('settings.header')),
    h('div', { class: 'card' }, h('h3', {}, t('settings.brandingTitle')), field('appName', t('settings.fieldAppName'), s.appName)),
    h('div', { class: 'card' }, h('h3', {}, t('settings.unitPricesTitle')), h('div', { class: 'grid2' },
      field('lunch', t('settings.fieldLunch'), s.unitPrices.lunch, 'number'),
      field('breakfast', t('settings.fieldBreakfast'), s.unitPrices.breakfast, 'number'),
      field('brunch', t('settings.fieldBrunch'), s.unitPrices.brunch, 'number'))),
    h('div', { class: 'card' }, h('h3', {}, t('settings.mealWindowsTitle')), winRow('breakfast'), winRow('lunch'), winRow('brunch')),
    h('div', { class: 'card' }, h('h3', {}, t('settings.timezoneTitle')), tz, tzList),
    h('div', { class: 'card' }, h('h3', {}, t('settings.graceTitle')),
      h('label', { style: 'display:flex;gap:8px;text-transform:none' }, graceOn, t('settings.graceEnabledLabel')),
      field('graceUnits', t('settings.fieldGraceUnits'), s.graceAllowanceUnits, 'number')),
    h('div', { class: 'card' }, h('h3', {}, t('settings.windowsRemindersTitle')), h('div', { class: 'grid2' },
      field('reversal', t('settings.fieldReversalWindow'), s.reversalWindowMinutes, 'number'),
      field('prepLead', t('settings.fieldPrepLead'), s.prepLeadMinutes, 'number'),
      field('purchaseLead', t('settings.fieldPurchaseLead'), s.purchaseLeadDays, 'number'))),
    h('div', { class: 'card' }, h('h3', {}, t('settings.upiTitle')),
      field('upiId', t('settings.fieldUpiId'), s.upiId), field('upiPayee', t('settings.fieldUpiPayee'), s.upiPayeeName)),
    h('button', { class: 'primary', onclick: save }, t('settings.saveBtn')));
};

// --- shell + router -----------------------------------------------------
function nav() {
  return [
    ['members', t('nav.members')], ['topups', t('nav.topups')], ['scans', t('nav.scans')],
    ['menu', t('nav.menu')], ['categories', t('nav.categories')], ['ingredients', t('nav.ingredients')],
    ['recipes', t('nav.recipes')], ['purchase', t('nav.purchase')], ['expenses', t('nav.expenses')],
    ['refunds', t('nav.refunds')], ['settings', t('nav.settings')], ['users', t('nav.users')],
  ];
}

function localeSwitcher() {
  const sel = h('select', {
    onchange: (e) => i18n.setLocale(e.target.value),
  }, ...LOCALES.map((loc) => h('option', { value: loc.code, ...(loc.code === i18n.locale ? { selected: true } : {}) }, loc.native)));
  return h('label', { style: 'display:inline-flex;gap:6px;align-items:center;text-transform:none' },
    h('span', { class: 'muted' }, t('common.language')), sel);
}

const spinner = () => h('div', { class: 'spinner' });

let _shellRoute = null;
let _mainEl = null;

async function render() {
  const app = $('#app');
  const route = (location.hash.replace('#/', '') || 'members');

  if (!api.token || route === 'login') {
    _shellRoute = null;
    app.replaceChildren(await views.login());
    return;
  }
  const role = localStorage.getItem('tiffin_role');
  const NAV = nav();
  const allowed = role === 'admin' ? NAV : NAV.filter(([k]) => ['topups', 'purchase'].includes(k));
  const view = views[route] || views.members;

  // Rebuild the shell only on a route *change*; a same-route re-render (after a
  // create/edit/delete) just swaps the main pane, so the nav never flashes and
  // the old content stays visible (dimmed) until the new data lands.
  if (_shellRoute !== route || !_mainEl || !document.body.contains(_mainEl)) {
    const side = h('nav', { class: 'side' },
      h('div', { class: 'brand' }, t('nav.brand')),
      ...allowed.map(([k, label]) => h('a', { href: '#/' + k, class: route === k ? 'active' : '' }, label)),
      h('div', { class: 'spacer' }),
      localeSwitcher(),
      h('div', { class: 'muted' }, localStorage.getItem('tiffin_user') + ' · ' + role),
      h('button', { class: 'ghost', onclick: () => { api.token = null; location.hash = '#/login'; } }, t('common.signOut')));
    _mainEl = h('main', {}, spinner());
    app.replaceChildren(h('div', { class: 'shell' }, side, _mainEl));
    _shellRoute = route;
  }
  _mainEl.classList.add('loading');
  try {
    const node = await view();
    _mainEl.classList.remove('loading');
    _mainEl.replaceChildren(node);
  } catch (e) {
    _mainEl.classList.remove('loading');
    _mainEl.replaceChildren(h('div', { class: 'card', style: 'border-color:var(--reject)' },
      h('h2', {}, t('common.couldNotLoad')), h('div', {}, e.message || String(e)),
      h('button', { onclick: render, style: 'margin-top:12px' }, t('common.retry'))));
  }
}

window.addEventListener('hashchange', render);
i18n.init().then(render);
