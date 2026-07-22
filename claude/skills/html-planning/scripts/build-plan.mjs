#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { sanitizePlan, validateHtml } from './sanitize-and-validate.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

function argsOf(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, '');
    if (!key || argv[i + 1] === undefined) throw new Error('Arguments must be --key value pairs.');
    out[key] = argv[i + 1];
  }
  return out;
}

const SCALAR_FIELDS = ['title', 'summary', 'objective', 'status', 'scope', 'risk', 'sourceRevision'];
const LIST_FIELDS = ['requirements', 'nonGoals', 'currentImplementation', 'failureHandling', 'verification', 'rollout', 'assumptions'];
const OBJECT_LIST_FIELDS = {
  successCriteria: ['text', 'check'],
  design: ['heading', 'body'],
  files: ['path', 'change', 'reason'],
  phases: ['title', 'prerequisite', 'deliverable', 'steps', 'verification'],
  risks: ['risk', 'impact', 'mitigation'],
  openDecisions: ['question', 'why', 'needed']
};

const esc = value => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
const idFor = value => String(value).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 50) || 'section';
const strings = value => Array.isArray(value) ? value.filter(item => typeof item === 'string') : [];

function normalizeRecord(value, fields) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const normalized = {};
  for (const field of fields) {
    if (field === 'steps' || field === 'verification') {
      if (Array.isArray(value[field])) normalized[field] = strings(value[field]);
    } else if (typeof value[field] === 'string') {
      normalized[field] = value[field];
    }
  }
  return normalized;
}

function normalizeInput(input) {
  const normalized = {};
  for (const field of SCALAR_FIELDS) {
    if (typeof input[field] === 'string') normalized[field] = input[field];
  }
  for (const field of LIST_FIELDS) {
    if (Array.isArray(input[field])) normalized[field] = strings(input[field]);
  }
  for (const [field, keys] of Object.entries(OBJECT_LIST_FIELDS)) {
    if (Array.isArray(input[field])) normalized[field] = input[field].map(item => normalizeRecord(item, keys));
  }
  return normalized;
}
const list = values => values?.length ? `<ul>${values.map(value => `<li>${esc(value)}</li>`).join('')}</ul>` : '';
const section = (id, title, body) => body ? `<section class="section" id="${id}"><h2>${esc(title)}</h2>${body}</section>` : '';
const table = (heads, rows) => rows.length ? `<div class="table-wrap"><table><thead><tr>${heads.map(head => `<th scope="col">${esc(head)}</th>`).join('')}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(cell => `<td>${cell}</td>`).join('')}</tr>`).join('')}</tbody></table></div>` : '';

function render(plan) {
  const parts = [];
  const toc = [];
  const add = (id, title, body) => { if (!body) return; parts.push(section(id, title, body)); toc.push(`<li><a href="#${id}">${esc(title)}</a></li>`); };

  const objective = [plan.objective ? `<p class="lede">${esc(plan.objective)}</p>` : '', table(['Criterion', 'Check'], (plan.successCriteria || []).map(item => [esc(item.text), esc(item.check || '—')]))].join('');
  add('objective', 'Objective and success', objective);
  add('scope', 'Requirements and boundaries', (plan.requirements?.length || plan.nonGoals?.length) ? `<div class="grid"><div class="card"><h3>Requirements</h3>${list(plan.requirements)}</div><div class="card"><h3>Non-goals</h3>${list(plan.nonGoals)}</div></div>` : '');
  add('current', 'Current implementation', list(plan.currentImplementation));
  add('design', 'Recommended design', plan.design?.length ? `<div class="grid">${plan.design.map(item => `<article class="card"><h3>${esc(item.heading)}</h3><p>${esc(item.body)}</p></article>`).join('')}</div>` : '');
  add('files', 'Files and interfaces', table(['Path / anchor', 'Expected change', 'Why this layer'], (plan.files || []).map(item => [`<code>${esc(item.path)}</code>`, esc(item.change), esc(item.reason || '—')])));
  add('sequence', 'Implementation sequence', plan.phases?.length ? plan.phases.map((phase, index) => `<article class="step"><div class="step-no">${String(index + 1).padStart(2, '0')}</div><div><h3>${esc(phase.title)}</h3><div class="mini"><div><strong>Prerequisite</strong>${esc(phase.prerequisite || 'None')}</div><div><strong>Deliverable</strong>${esc(phase.deliverable || 'Defined by phase')}</div><div><strong>Verification</strong>${esc((phase.verification || []).join('; ') || 'See verification plan')}</div></div>${list(phase.steps)}</div></article>`).join('') : '');
  add('failure', 'Failure handling', list(plan.failureHandling));
  add('verification', 'Verification', list(plan.verification));
  add('rollout', 'Rollout and rollback', list(plan.rollout));
  add('risks', 'Risks', table(['Risk', 'Impact', 'Mitigation'], (plan.risks || []).map(item => [esc(item.risk), esc(item.impact || '—'), esc(item.mitigation || '—')])));
  add('assumptions', 'Assumptions', list(plan.assumptions));
  add('decisions', 'Open decisions', plan.openDecisions?.length ? plan.openDecisions.map(item => `<details><summary>${esc(item.question)}</summary><p>${esc(item.why || '')}</p>${item.needed ? `<p><strong>Needed:</strong> ${esc(item.needed)}</p>` : ''}</details>`).join('') : '');
  return { body: parts.join('\n'), toc: toc.join('') };
}

function safeJson(value) {
  return JSON.stringify(value)
    .replace(/&/g, '\\u0026')
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .split(String.fromCharCode(0x2028)).join('\\u2028')
    .split(String.fromCharCode(0x2029)).join('\\u2029');
}

async function existingTitle(file) {
  try {
    const html = await fs.readFile(file, 'utf8');
    const current = html.match(/<template\s+id=["']plan-data["']>([\s\S]*?)<\/template>/i);
    const legacy = html.match(/<script\s+type=["']application\/json["']\s+id=["']plan-data["']>([\s\S]*?)<\/script>/i);
    return JSON.parse(current?.[1] || legacy?.[1]).title;
  } catch { return null; }
}

async function main() {
  const args = argsOf(process.argv.slice(2));
  if (!args.input || !args.project || !args.slug) throw new Error('Usage: build-plan.mjs --input plan.json --project project-root --slug plan-slug');
  const projectRoot = path.resolve(args.project);
  const input = JSON.parse(await fs.readFile(path.resolve(args.input), 'utf8'));
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('Plan input must be a JSON object.');
  const { plan, report } = sanitizePlan(normalizeInput(input), { projectRoot, homeDir: os.homedir() });
  if (!plan.title || !plan.summary) throw new Error('Plan input requires title and summary.');
  const baseSlug = idFor(args.slug);
  const generatedAt = new Date().toISOString();
  const canonical = { ...plan, slug: baseSlug, generatedAt, security: { redactions: report.counts, blockPublish: report.blockPublish } };
  const outputDir = path.join(projectRoot, '.claude', 'plans');
  await fs.mkdir(outputDir, { recursive: true });
  let output = path.join(outputDir, `${baseSlug}.html`);
  const priorTitle = await existingTitle(output);
  if (priorTitle && priorTitle !== canonical.title) {
    const stableIdentity = `${baseSlug}\0${canonical.title.trim().toLowerCase()}`;
    const suffix = crypto.createHash('sha256').update(stableIdentity).digest('hex').slice(0, 8);
    output = path.join(outputDir, `${baseSlug}-${suffix}.html`);
    canonical.slug = `${baseSlug}-${suffix}`;
  }
  const template = await fs.readFile(path.join(here, '..', 'assets', 'plan-template.html'), 'utf8');
  const rendered = render(canonical);
  const replacements = {
    '{{TITLE}}': esc(canonical.title), '{{SUMMARY}}': esc(canonical.summary), '{{STATUS}}': esc(canonical.status || 'Proposed'),
    '{{SCOPE}}': esc(canonical.scope || 'Unspecified'), '{{RISK}}': esc(canonical.risk || 'Unspecified'), '{{GENERATED}}': esc(generatedAt.replace('T', ' ').replace(/:\d{2}\.\d{3}Z$/, ' UTC')),
    '{{BODY}}': rendered.body, '{{TOC}}': rendered.toc, '{{PLAN_DATA}}': safeJson(canonical)
  };
  let html = template;
  for (const [key, value] of Object.entries(replacements)) html = html.replaceAll(key, value);
  validateHtml(html, { allowBlocked: true });
  const temp = `${output}.${process.pid}.tmp`;
  await fs.writeFile(temp, html, { encoding: 'utf8', mode: 0o600 });
  await fs.rename(temp, output);
  process.stdout.write(`${JSON.stringify({ ok: true, path: output, slug: canonical.slug, redactions: report.counts, blockPublish: report.blockPublish })}\n`);
}

main().catch(error => { process.stderr.write(`${JSON.stringify({ error: error.message })}\n`); process.exitCode = 1; });
