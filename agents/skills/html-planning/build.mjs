#!/usr/bin/env node
// html-planning renderer — plan.json in, static HTML plan page out.
// Zero dependencies, Node 20+. Markup transcribed from the "Agent Plan System"
// design (layouts 1a Dossier / 1c Ledger). Output contains no <script>.
//
// Usage: node build.mjs <path/to/plan.json>
// Prints the absolute path of the written HTML file as its only stdout line.

import { readFileSync, writeFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, dirname, join, basename } from 'node:path';

// ---------------------------------------------------------------- escaping

const esc = (s) =>
  String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// ---------------------------------------------------------------- validation

function fail(msg) {
  console.error(`plan.json invalid: ${msg}`);
  process.exit(1);
}

function validate(p) {
  for (const f of ['title', 'intent', 'project']) {
    if (!p[f] || typeof p[f] !== 'string') fail(`"${f}" is required`);
  }
  if (!Array.isArray(p.questions)) fail('"questions" must be an array (may be empty)');
  p.questions.forEach((q, i) => {
    if (!q.q) fail(`questions[${i}] missing "q"`);
    if (!q.default) fail(`questions[${i}] missing "default" — silence must be safe (rule 02)`);
  });
  if (!p.approach?.thesis) fail('"approach.thesis" is required');
  if (!Array.isArray(p.steps) || p.steps.length === 0) fail('"steps" must be a non-empty array');
  p.steps.forEach((s, i) => {
    if (!s.title) fail(`steps[${i}] missing "title"`);
    if (!Array.isArray(s.files) || s.files.length === 0)
      fail(`steps[${i}] "${s.title}" has no files — a step with no path is a wish (rule 03)`);
    if (!s.verify) fail(`steps[${i}] "${s.title}" missing "verify" (rule 03)`);
  });
  if (!Array.isArray(p.tests) || p.tests.length === 0) fail('"tests" must be a non-empty array');
  if (!Array.isArray(p.doneWhen) || p.doneWhen.length === 0) fail('"doneWhen" must be a non-empty array');
  const statuses = ['awaiting review', 'blocked', 'approved', 'in progress', 'draft', 'superseded'];
  if (p.status && !statuses.includes(p.status)) fail(`"status" must be one of: ${statuses.join(' / ')}`);
}

// ---------------------------------------------------------------- derivation

const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

function derive(p) {
  const files = p.steps.flatMap((s) => s.files);
  let add = 0, del = 0, hasDiff = false;
  for (const s of p.steps) {
    const m = /^\+(\d+)\s+[−-](\d+)$/.exec(s.diff ?? '');
    if (m) { add += +m[1]; del += +m[2]; hasDiff = true; }
  }
  const now = new Date();
  return {
    rev: p.rev ?? 1,
    status: p.status ?? 'awaiting review',
    counters: {
      steps: p.steps.length,
      files: new Set(files.map((f) => f.path)).size,
      diff: hasDiff ? `+${add} −${del}` : null,
      tests: p.tests.length,
      auto: p.tests.filter((t) => t.kind === 'auto').length,
      open: p.questions.length,
    },
    layout: p.layout ?? (p.steps.length > 6 || new Set(files.map((f) => f.path)).size > 12 ? 'ledger' : 'dossier'),
    date: `${now.getDate()} ${MONTHS[now.getMonth()]}`,
  };
}

function slugify(title) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 50)
    .replace(/-+$/, '');
}

function nextPlanNumber(dir) {
  const nums = readdirSync(dir)
    .map((f) => /^(\d{3})-/.exec(f)?.[1])
    .filter(Boolean)
    .map(Number);
  return nums.length ? Math.max(...nums) + 1 : 1;
}

// ---------------------------------------------------------------- primitives
// Fonts: sans = human judgment, mono = machine facts.
const SANS = `'IBM Plex Sans',system-ui,sans-serif`;
const MONO = `'IBM Plex Mono',ui-monospace,Menlo,monospace`;

// Section label, e.g. `// steps · 5`
const label = (text, color = '#7a746d') =>
  `<div style="font:500 10.5px/1 ${MONO};letter-spacing:.16em;text-transform:uppercase;color:${color}">${text}</div>`;

const STATUS_STYLE = {
  'awaiting review': 'background:#e0764f;color:#160e09',
  blocked: 'border:1px solid rgba(224,118,79,.45);color:#eb8f6b',
  approved: 'background:#d9d4ce;color:#181816',
  'in progress':
    'background-color:rgba(224,118,79,.12);background-image:repeating-linear-gradient(45deg,rgba(224,118,79,.6) 0 4px,transparent 4px 8px);color:#f2efeb',
  draft: 'border:1px solid rgba(255,255,255,.16);color:#a8a29b',
  superseded: 'border:1px solid rgba(255,255,255,.1);color:#5f5a54',
};

const badge = (status) =>
  `<span style="padding:5px 9px;border-radius:4px;${STATUS_STYLE[status]};font:600 9.5px/1 ${MONO};letter-spacing:.12em;text-transform:uppercase">${esc(status)}</span>`;

const chip = (f) => {
  const action =
    f.action === 'del'
      ? `<span style="color:#6d6862;text-decoration:line-through">del</span> `
      : f.action === 'new'
        ? `<span style="color:#eb8f6b">new</span> `
        : f.action === 'edit'
          ? `<span style="color:#7a746d">edit</span> `
          : '';
  return `<span style="padding:3px 7px;border:1px solid rgba(255,255,255,.11);border-radius:4px;background:rgba(255,255,255,.03);font:400 11.5px/1.4 ${MONO};color:#cfc9c3">${action}${esc(f.path)}</span>`;
};

const counterCell = (name, value, sub, accent, last) => `
<div style="padding:11px 14px 12px;${accent ? 'background:rgba(224,118,79,.07)' : ''}${!last && !accent ? ';border-right:1px solid rgba(255,255,255,.075)' : ''}">
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:${accent ? '#a86a4c' : '#5f5a54'}">${name}</div>
<div style="margin-top:7px;font:500 17px/1 ${MONO};color:${accent ? '#eb8f6b' : '#f2efeb'}">${value}${sub ? ` <span style="font-size:11.5px;color:#7a746d">${sub}</span>` : ''}</div>
</div>`;

// ---------------------------------------------------------------- dossier (design 1a)

function dossierQuestion(q, i) {
  const options = (q.options ?? [])
    .map(
      (o) =>
        `<span style="padding:4px 8px;border:1px solid rgba(255,255,255,.14);border-radius:4px;background:rgba(255,255,255,.03);font:400 11.5px/1.3 ${MONO};color:#cfc9c3">${esc(o)}</span>`,
    )
    .join('\n');
  return `
<div style="display:grid;grid-template-columns:auto 1fr;gap:14px;padding:15px 17px;border:1px solid rgba(224,118,79,.3);background:rgba(224,118,79,.05);border-radius:7px">
<span style="padding:4px 6px;height:fit-content;border-radius:4px;background:rgba(224,118,79,.18);color:#eb8f6b;font:600 10px/1 ${MONO};letter-spacing:.1em">Q${i + 1}</span>
<div>
<div style="font:500 15px/1.42 ${SANS};color:#f2efeb">${esc(q.q)}</div>
${q.consequence ? `<p style="margin:7px 0 0;max-width:62ch;font:400 13.5px/1.6 ${SANS};color:#a8a29b;text-wrap:pretty">${esc(q.consequence)}</p>` : ''}
${options ? `<div style="display:flex;flex-wrap:wrap;gap:7px;margin-top:12px">\n${options}\n</div>` : ''}
<div style="margin-top:12px;font:400 11.5px/1.4 ${MONO};color:#eb8f6b">→ default if you say nothing: ${esc(q.default)}</div>
</div>
</div>`;
}

function dossierStep(s, i, total) {
  const n = String(i + 1).padStart(2, '0');
  const last = i === total - 1;
  const blocked = s.blockedOn
    ? ` <span style="margin-left:7px;padding:2px 6px;border-radius:3px;border:1px solid rgba(224,118,79,.4);color:#eb8f6b;font:600 9px/1.5 ${MONO};letter-spacing:.1em;text-transform:uppercase;vertical-align:1px">depends on ${esc(s.blockedOn)}</span>`
    : '';
  return `
<div style="display:flex;flex-direction:column;align-items:center"><div style="width:27px;height:27px;flex:none;border:1px solid rgba(255,255,255,.17);border-radius:5px;display:flex;align-items:center;justify-content:center;font:500 11px/1 ${MONO};color:#f2efeb">${n}</div>${last ? '' : `<div style="width:1px;flex:1;min-height:12px;background:rgba(255,255,255,.1);margin-top:8px"></div>`}</div>
<div style="padding:3px 0 ${last ? '4px' : '22px'}">
<div style="display:flex;justify-content:space-between;gap:16px;align-items:baseline">
<div style="font:500 15px/1.4 ${SANS};color:#f2efeb">${esc(s.title)}${blocked}</div>
${s.diff ? `<div style="font:400 11px/1 ${MONO};color:#6d6862">${esc(s.diff)}</div>` : ''}
</div>
${s.rationale ? `<p style="margin:7px 0 0;max-width:64ch;font:400 13.5px/1.6 ${SANS};color:#a8a29b;text-wrap:pretty">${esc(s.rationale)}</p>` : ''}
<div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:11px">
${s.files.map(chip).join('\n')}
</div>
<div style="margin-top:10px;font:400 11.5px/1.4 ${MONO};color:#7a746d">verify · <span style="color:#cfc9c3">${esc(s.verify)}</span></div>
</div>`;
}

const dossierTestRow = (t) => {
  const kindBadge =
    t.kind === 'manual'
      ? `<span style="padding:3px 6px;border-radius:3px;border:1px solid rgba(224,118,79,.45);color:#eb8f6b;font:600 9px/1 ${MONO};letter-spacing:.1em;text-transform:uppercase">manual</span>`
      : `<span style="padding:3px 6px;border-radius:3px;background:rgba(255,255,255,.07);color:#a8a29b;font:600 9px/1 ${MONO};letter-spacing:.1em;text-transform:uppercase">auto</span>`;
  return `
<div style="border-top:1px solid rgba(255,255,255,.07);padding:11px 0">${kindBadge}</div>
<div style="border-top:1px solid rgba(255,255,255,.07);padding:11px 0;font:400 13.5px/1.5 ${SANS};color:#e6e1db">${esc(t.condition)}</div>
<div style="border-top:1px solid rgba(255,255,255,.07);padding:11px 0;font:400 13.5px/1.5 ${SANS};color:#a8a29b">${esc(t.expected)}</div>`;
};

const EFFORT_FILL = {
  accent: `background:#e0764f`,
  hatch: `background-color:rgba(224,118,79,.12);background-image:repeating-linear-gradient(45deg,rgba(224,118,79,.75) 0 5px,transparent 5px 10px)`,
  light: `background:#d9d4ce`,
  inert: `background:rgba(255,255,255,.13)`,
};
const EFFORT_TEXT = { accent: '#160e09', hatch: '#f2efeb', light: '#181816', inert: '#a8a29b' };

function effortBar(effort) {
  const segs = effort
    .map(
      (e, i) =>
        `<div style="flex:${i === effort.length - 1 ? '1 1 auto' : `0 0 ${e.share}%`};${EFFORT_FILL[e.fill] ?? EFFORT_FILL.inert};border-radius:3px;display:flex;align-items:center;padding-left:10px;font:500 9.5px ${MONO};letter-spacing:.11em;text-transform:uppercase;color:${EFFORT_TEXT[e.fill] ?? '#a8a29b'}">${esc(e.label)}</div>`,
    )
    .join('\n');
  return `
<div style="margin-top:22px;position:relative">
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:#5f5a54">// where the work is</div>
<div style="display:flex;gap:3px;margin-top:9px;height:30px">
${segs}
</div>
<div style="margin-top:8px;font:400 10.5px/1 ${MONO};color:#5f5a54">hatched = highest uncertainty · segment width = share of estimated diff</div>
</div>`;
}

function renderDossier(p, d) {
  const c = d.counters;
  const questions = p.questions.length
    ? `
<div style="padding:26px 36px 28px;border-top:1px solid rgba(255,255,255,.075);background:rgba(224,118,79,.022)">
<div style="display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:15px">
${label(`// blocked on you · ${c.open}`, '#eb8f6b')}
<div style="font:400 10.5px/1 ${MONO};color:#5f5a54">silence = the stated default is taken</div>
</div>
<div style="display:grid;gap:11px">
${p.questions.map(dossierQuestion).join('\n')}
</div>
</div>`
    : '';

  const dropped = (p.approach.dropped ?? [])
    .map(
      (a) => `
<div style="display:grid;grid-template-columns:auto 1fr;gap:11px;align-items:baseline">
<span style="font:400 12px/1.5 ${MONO};color:#6d6862">✕</span>
<div style="font:400 13.5px/1.55 ${SANS};color:#a8a29b"><span style="color:#e6e1db">${esc(a.what)}.</span> ${esc(a.why)}</div>
</div>`,
    )
    .join('\n');

  const risks = p.risks?.length
    ? `
<div style="padding:26px 30px 28px 36px;border-right:1px solid rgba(255,255,255,.075)">
${label('// risks')}
<div style="display:grid;gap:14px;margin-top:15px">
${p.risks
  .map(
    (r) => `
<div>
<div style="font:400 13.5px/1.5 ${SANS};color:#e6e1db">${esc(r.risk)}</div>
<div style="margin-top:5px;font:400 11.5px/1.5 ${MONO};color:#7a746d">↳ ${esc(r.mitigation)}</div>
</div>`,
  )
  .join('\n')}
</div>
</div>`
    : '';

  const doneWhen = `
<div style="padding:26px 36px 28px${p.risks?.length ? ' 30px' : ''}">
${label('// done when')}
<div style="display:grid;gap:11px;margin-top:15px">
${p.doneWhen
  .map(
    (t) =>
      `<div style="display:grid;grid-template-columns:auto 1fr;gap:10px;align-items:start"><span style="width:11px;height:11px;margin-top:4px;border:1px solid rgba(255,255,255,.28);border-radius:2px"></span><div style="font:400 13.5px/1.5 ${SANS};color:#e6e1db">${esc(t)}</div></div>`,
  )
  .join('\n')}
</div>
</div>`;

  return `
<div style="max-width:900px;margin:0 auto;background:#0f0f0e;border:1px solid rgba(255,255,255,.09);border-radius:10px;overflow:hidden">

<div style="padding:32px 36px 30px;position:relative;overflow:hidden">
<div aria-hidden="true" style="position:absolute;top:2px;right:20px;font:600 96px/1 ${MONO};letter-spacing:-.03em;color:transparent;-webkit-text-stroke:1px rgba(255,255,255,.055)">${d.nnn}</div>
<div style="display:flex;align-items:center;justify-content:space-between;gap:20px;position:relative">
${label(`// plan ${d.nnn} · ${esc(p.project)}`)}
${badge(d.status)}
</div>
<h1 style="margin:15px 0 0;max-width:24ch;font:600 31px/1.14 ${SANS};letter-spacing:-.022em;color:#f2efeb;position:relative">${esc(p.title)}</h1>
<p style="margin:13px 0 0;max-width:66ch;font:400 15px/1.62 ${SANS};color:#a8a29b;text-wrap:pretty">${esc(p.intent)}</p>

<div style="display:grid;grid-template-columns:repeat(4,1fr);margin-top:24px;border:1px solid rgba(255,255,255,.075);border-radius:6px;overflow:hidden;position:relative">
${counterCell('steps', c.steps)}
${counterCell('files touched', c.files, c.diff ? esc(c.diff) : '')}
${counterCell('tests', c.tests, `${c.auto} auto`)}
${counterCell('open questions', c.open, '', true, true)}
</div>
${p.effort?.length && c.steps > 6 ? effortBar(p.effort) : ''}
</div>
${questions}

<div style="padding:26px 36px 28px;border-top:1px solid rgba(255,255,255,.075)">
${label('// approach')}
<div style="margin-top:14px;font:500 16px/1.45 ${SANS};color:#f2efeb;max-width:56ch">${esc(p.approach.thesis)}</div>
${p.approach.rationale ? `<p style="margin:9px 0 0;max-width:66ch;font:400 14px/1.65 ${SANS};color:#a8a29b;text-wrap:pretty">${esc(p.approach.rationale)}</p>` : ''}
${
  dropped
    ? `
<div style="display:grid;gap:9px;margin-top:16px;padding-top:15px;border-top:1px solid rgba(255,255,255,.06)">
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:#5f5a54">considered and dropped</div>
${dropped}
</div>`
    : ''
}
</div>

<div style="padding:26px 36px 22px;border-top:1px solid rgba(255,255,255,.075)">
<div style="display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:18px">
${label(`// steps · ${c.steps}`)}
<div style="font:400 10.5px/1 ${MONO};color:#5f5a54">each step ships and is verifiable on its own</div>
</div>
<div style="display:grid;grid-template-columns:34px 1fr;gap:16px">
${p.steps.map((s, i) => dossierStep(s, i, p.steps.length)).join('\n')}
</div>
</div>

<div style="padding:26px 36px 28px;border-top:1px solid rgba(255,255,255,.075)">
<div style="margin-bottom:14px">${label(`// test plan · ${c.tests}`)}</div>
<div style="display:grid;grid-template-columns:72px 1.1fr 1fr;gap:0 18px;align-items:baseline">
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:#5f5a54;padding-bottom:9px">kind</div>
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:#5f5a54;padding-bottom:9px">case</div>
<div style="font:500 9.5px/1 ${MONO};letter-spacing:.14em;text-transform:uppercase;color:#5f5a54;padding-bottom:9px">expected</div>
${p.tests.map(dossierTestRow).join('\n')}
</div>
</div>

<div style="display:grid;grid-template-columns:${p.risks?.length ? '1fr 1fr' : '1fr'};border-top:1px solid rgba(255,255,255,.075)">
${risks}
${doneWhen}
</div>
${p.callout ? `<div style="margin:0 36px 26px;padding:14px 16px;border-left:2px solid #e0764f;background:rgba(255,255,255,.028);font:400 13px/1.6 ${SANS};color:#cfc9c3;text-wrap:pretty">${esc(p.callout)}</div>` : ''}

<div style="display:flex;justify-content:space-between;gap:20px;padding:16px 36px 18px;border-top:1px solid rgba(255,255,255,.075);background:rgba(255,255,255,.018);font:400 10.5px/1.5 ${MONO};color:#5f5a54">
<div>${p.notInScope?.length ? `out of scope · ${p.notInScope.map(esc).join(' · ')}` : ''}</div>
<div>rev ${d.rev} · ${d.date}</div>
</div>

</div>`;
}

// ---------------------------------------------------------------- ledger (design 1c)

function ledgerQuestion(q, i) {
  const opts = q.options?.length ? ` <span style="color:#7a746d">${q.options.map(esc).join(' | ')}</span>` : '';
  const blocks = q.blocksStep ? ` <span style="color:#5f5a54">· blocks step ${esc(String(q.blocksStep))}</span>` : '';
  return `
<div style="display:grid;grid-template-columns:26px 1fr;gap:10px;padding:9px 11px;background:rgba(224,118,79,.06);border-left:2px solid #e0764f">
<span style="font:500 11.5px/1.6 ${MONO};color:#eb8f6b">Q${i + 1}</span>
<div style="font:400 12.5px/1.6 ${MONO};color:#e6e1db">${esc(q.q)}${opts}<br><span style="color:#eb8f6b">→ ${esc(q.default)}</span>${blocks}</div>
</div>`;
}

function ledgerStep(s, i) {
  const n = String(i + 1).padStart(2, '0');
  const blocked = Boolean(s.blockedOn);
  const marker = blocked ? '◆' : '▸';
  const markerColor = blocked ? '#eb8f6b' : '#cfc9c3';
  const files = s.files
    .map((f) => `${f.action ? `${f.action} ` : ''}${f.path}`)
    .map(esc)
    .join(' · ');
  return `
<div style="display:grid;grid-template-columns:16px 30px 1fr 62px;gap:10px;padding:8px 0;border-top:1px solid rgba(255,255,255,.06);align-items:baseline${blocked ? ';background:rgba(224,118,79,.05)' : ''}">
<span style="font:400 11.5px/1.6 ${MONO};color:${markerColor}">${marker}</span><span style="font:500 11.5px/1.6 ${MONO};color:${blocked ? '#eb8f6b' : '#6d6862'}">${n}</span>
<div style="font:400 12.5px/1.6 ${MONO};color:#e6e1db">${esc(s.title)}${blocked ? ` <span style="color:#eb8f6b">· waiting on ${esc(s.blockedOn)}</span>` : ''}<br><span style="color:#7a746d">${files}</span><br><span style="color:#5f5a54">verify ${esc(s.verify)}</span></div>
<span style="font:400 10.5px/1.6 ${MONO};color:#5f5a54;text-align:right">${s.diff ? esc(s.diff) : ''}</span>
</div>`;
}

function renderLedger(p, d) {
  const c = d.counters;
  const summary = [
    `${c.steps} steps`,
    `${c.files} files`,
    c.diff ? esc(c.diff) : null,
    `${c.tests} tests`,
    c.open ? `<span style="color:#eb8f6b">${c.open} open</span>` : null,
  ]
    .filter(Boolean)
    .join(' · ');

  const questions = p.questions.length
    ? `
<div style="padding:20px 28px 8px">
<div style="margin-bottom:11px">${label('// open · answer or the default is taken', '#eb8f6b').replace('10.5px', '10px')}</div>
<div style="display:grid;gap:1px">
${p.questions.map(ledgerQuestion).join('\n')}
</div>
</div>`
    : '';

  const tests = p.tests
    .map((t) => {
      const kind =
        t.kind === 'manual'
          ? `<span style="color:#eb8f6b">man.</span>`
          : `<span style="color:#5f5a54">auto</span>`;
      return `<div>${kind} ${esc(t.condition)} <span style="color:#5f5a54">→</span> <span style="color:#e6e1db">${esc(t.expected)}</span></div>`;
    })
    .join('\n');

  const risks = p.risks?.length
    ? `
<div style="margin-top:16px;margin-bottom:11px">${label('// risks').replace('10.5px', '10px')}</div>
<div style="display:grid;gap:7px;font:400 12px/1.55 ${MONO};color:#a8a29b">
${p.risks.map((r) => `<div>${esc(r.risk)} <span style="color:#5f5a54">↳ ${esc(r.mitigation)}</span></div>`).join('\n')}
</div>`
    : '';

  const notInScope = p.notInScope?.length
    ? `
<div style="margin-top:16px;margin-bottom:11px">${label('// not in scope').replace('10.5px', '10px')}</div>
<div style="display:grid;gap:7px;font:400 12px/1.55 ${MONO};color:#7a746d">
${p.notInScope.map((x) => `<div>— ${esc(x)}</div>`).join('\n')}
</div>`
    : '';

  return `
<div style="max-width:800px;margin:0 auto;background:#0f0f0e;border:1px solid rgba(255,255,255,.09);border-radius:10px;overflow:hidden">

<div style="padding:26px 28px 22px;border-bottom:1px solid rgba(255,255,255,.075);position:relative;overflow:hidden">
<div aria-hidden="true" style="position:absolute;top:-8px;right:14px;font:600 78px/1 ${MONO};letter-spacing:-.03em;color:transparent;-webkit-text-stroke:1px rgba(255,255,255,.05)">${d.nnn}</div>
<div style="display:flex;justify-content:space-between;align-items:baseline;gap:16px;position:relative">
<div style="font:500 13px/1.5 ${MONO};color:#f2efeb">plan/${d.nnn} <span style="color:#5f5a54">·</span> ${esc(p.project)}${p.branch ? `@${esc(p.branch)}` : ''}</div>
${badge(d.status).replace('9.5px/1', '9px/1')}
</div>
<div style="margin-top:12px;font:400 13px/1.6 ${MONO};color:#a8a29b;max-width:70ch;position:relative">${esc(p.intent)}</div>
<div style="margin-top:14px;font:400 11px/1.5 ${MONO};color:#5f5a54;position:relative">${summary}</div>
</div>
${questions}

<div style="padding:20px 28px 10px">
<div style="display:flex;justify-content:space-between;align-items:baseline;gap:14px;margin-bottom:11px">
${label('// steps').replace('10.5px', '10px')}
<div style="font:400 10px/1 ${MONO};color:#5f5a54">◆ blocked &nbsp; ▸ ready &nbsp; ✓ done</div>
</div>
<div style="display:grid">
${p.steps.map(ledgerStep).join('\n')}
</div>
</div>

<div style="display:grid;grid-template-columns:1fr 1fr;border-top:1px solid rgba(255,255,255,.075);margin-top:14px">
<div style="padding:20px 22px 22px 28px;border-right:1px solid rgba(255,255,255,.075)">
<div style="margin-bottom:11px">${label('// tests').replace('10.5px', '10px')}</div>
<div style="display:grid;gap:7px;font:400 12px/1.55 ${MONO};color:#a8a29b">
${tests}
</div>
${risks}
</div>
<div style="padding:20px 28px 22px 22px">
<div style="margin-bottom:11px">${label('// done when').replace('10.5px', '10px')}</div>
<div style="display:grid;gap:8px;font:400 12px/1.55 ${MONO};color:#e6e1db">
${p.doneWhen.map((t) => `<div><span style="color:#5f5a54">[ ]</span> ${esc(t)}</div>`).join('\n')}
</div>
${notInScope}
</div>
</div>
${p.callout ? `<div style="margin:0 28px 22px;padding:12px 15px;border-left:2px solid #e0764f;background:rgba(255,255,255,.028);font:400 12.5px/1.6 ${SANS};color:#cfc9c3">${esc(p.callout)}</div>` : ''}

<div style="display:flex;justify-content:flex-end;padding:12px 28px 14px;border-top:1px solid rgba(255,255,255,.075);font:400 10.5px/1.5 ${MONO};color:#5f5a54">rev ${d.rev} · ${d.date}</div>

</div>`;
}

// ---------------------------------------------------------------- page shell

function renderPage(p, d) {
  const body = d.layout === 'ledger' ? renderLedger(p, d) : renderDossier(p, d);
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>plan ${d.nnn} · ${esc(p.title)}</title>
<style>
/* Postplan's CSP allows only inline styles — no external fonts there. This
   @import loads IBM Plex for local/file:// viewing and fails soft to the
   system stacks below on the published copy. */
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600&display=swap');
body{margin:0;padding:40px 24px 64px;background:#080807;font-family:${SANS};-webkit-font-smoothing:antialiased}
</style>
</head>
<body>
${body}
</body>
</html>
`;
}

// ---------------------------------------------------------------- main

function main() {
  const arg = process.argv[2];
  if (!arg) {
    console.error('usage: node build.mjs <path/to/plan.json>');
    process.exit(1);
  }
  const jsonPath = resolve(arg);
  const plan = JSON.parse(readFileSync(jsonPath, 'utf8'));
  validate(plan);

  const dir = dirname(jsonPath);
  const d = derive(plan);

  if (!plan.planNumber) {
    plan.planNumber = nextPlanNumber(dir);
  }
  d.nnn = String(plan.planNumber).padStart(3, '0');

  const slug = slugify(plan.title);
  const stem = `${d.nnn}-${slug}`;
  const finalJson = join(dir, `${stem}.json`);

  // Persist assigned number + canonical name so every rebuild is a revision.
  writeFileSync(finalJson, JSON.stringify(plan, null, 2) + '\n');
  if (basename(jsonPath) !== `${stem}.json`) {
    rmSync(jsonPath, { force: true });
  }

  const htmlPath = join(dir, `${stem}.html`);
  writeFileSync(htmlPath, renderPage(plan, d));
  console.log(htmlPath);
}

main();
