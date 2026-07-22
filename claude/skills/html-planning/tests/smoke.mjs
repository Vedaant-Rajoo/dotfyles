#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { extractPlanData, validateHtml } from '../scripts/sanitize-and-validate.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const skill = path.resolve(here, '..');
const build = path.join(skill, 'scripts', 'build-plan.mjs');
const publish = path.join(skill, 'scripts', 'publish-plan.mjs');

function run(script, args, expected = 0, env = process.env) {
  const result = spawnSync(process.execPath, [script, ...args], { encoding: 'utf8', env });
  assert.equal(result.status, expected, `Unexpected exit ${result.status}: ${result.stderr}`);
  return result;
}

function rejected(html, pattern) {
  assert.throws(() => validateHtml(html), pattern);
}

const required = [
  'SKILL.md', 'assets/plan-template.html', 'references/plan-content.md',
  'references/security-and-publishing.md', 'references/html-contract.md',
  'scripts/build-plan.mjs', 'scripts/sanitize-and-validate.mjs', 'scripts/publish-plan.mjs'
];
for (const relative of required) assert.ok(fs.existsSync(path.join(skill, relative)), `Missing ${relative}`);
const skillText = await fsp.readFile(path.join(skill, 'SKILL.md'), 'utf8');
assert.match(skillText, /^---\nname: html-planning\n/m);
assert.match(skillText, /user-invocable: true/);
assert.match(skillText, /plan this feature/);
assert.match(skillText, /postplan 0\.0\.4/i);
assert.doesNotMatch(skillText, /htmlbin/i);

const root = await fsp.mkdtemp(path.join(os.tmpdir(), 'html-planning-test-'));
try {
  const safe = run(build, ['--input', path.join(here, 'fixtures', 'safe-plan.json'), '--project', root, '--slug', 'invoice-export']);
  const safeResult = JSON.parse(safe.stdout);
  assert.equal(safeResult.ok, true);
  assert.equal(safeResult.blockPublish, false);
  assert.ok(safeResult.path.startsWith(path.join(root, '.claude', 'plans')));
  const safeHtml = await fsp.readFile(safeResult.path, 'utf8');
  const safePlan = validateHtml(safeHtml);
  assert.equal(safePlan.title, 'Add resilient invoice export');
  assert.equal(extractPlanData(safeHtml).title, safePlan.title);
  assert.match(safeHtml, /Add resilient invoice export/);
  assert.match(safeHtml, /<template id="plan-data">/);
  assert.doesNotMatch(safeHtml, /\{\{[A-Z0-9_]+\}\}/);
  assert.doesNotMatch(safeHtml, /<script\b/i);
  assert.doesNotMatch(safeHtml, /Copy Markdown|Download JSON|Export controls require JavaScript/);
  assert.equal((await fsp.stat(safeResult.path)).mode & 0o777, 0o600);

  const filteredInput = path.join(root, 'filtered-input.json');
  const filteredPlan = JSON.parse(await fsp.readFile(path.join(here, 'fixtures', 'safe-plan.json'), 'utf8'));
  filteredPlan.requirements = [...(filteredPlan.requirements || []), 'Credential pp_abcdefghijklmnopqrstuvwxyz1234567890'];
  filteredPlan.privateContext = 'must not be embedded';
  filteredPlan.successCriteria[0].privateContext = 'nested secret must not be embedded';
  await fsp.writeFile(filteredInput, JSON.stringify(filteredPlan));
  const filtered = run(build, ['--input', filteredInput, '--project', root, '--slug', 'filtered-plan']);
  const filteredHtml = await fsp.readFile(JSON.parse(filtered.stdout).path, 'utf8');
  assert.doesNotMatch(filteredHtml, /pp_abcdefghijklmnopqrstuvwxyz1234567890|must not be embedded|nested secret/);
  assert.equal(extractPlanData(filteredHtml).security.redactions['known-token'], 1);

  const collisionA = { ...filteredPlan, title: 'Collision owner A', requirements: [] };
  const collisionB = { ...filteredPlan, title: 'Collision owner B', requirements: [] };
  const collisionAPath = path.join(root, 'collision-a.json');
  const collisionBPath = path.join(root, 'collision-b.json');
  await fsp.writeFile(collisionAPath, JSON.stringify(collisionA));
  await fsp.writeFile(collisionBPath, JSON.stringify(collisionB));
  run(build, ['--input', collisionAPath, '--project', root, '--slug', 'collision']);
  const collisionFirst = JSON.parse(run(build, ['--input', collisionBPath, '--project', root, '--slug', 'collision']).stdout).path;
  await new Promise(resolve => setTimeout(resolve, 20));
  const collisionSecond = JSON.parse(run(build, ['--input', collisionBPath, '--project', root, '--slug', 'collision']).stdout).path;
  assert.equal(collisionSecond, collisionFirst);
  collisionB.summary = 'Revised content for the same colliding plan';
  await fsp.writeFile(collisionBPath, JSON.stringify(collisionB));
  const collisionRevised = JSON.parse(run(build, ['--input', collisionBPath, '--project', root, '--slug', 'collision']).stdout).path;
  assert.equal(collisionRevised, collisionFirst);

  rejected(safeHtml.replace('</body>', '<script>void 0</script></body>'), /Script elements/);
  rejected(safeHtml.replace('</body>', '<form></form></body>'), /Postplan-forbidden/);
  rejected(safeHtml.replace('</body>', '<iframe></iframe></body>'), /Postplan-forbidden/);
  rejected(safeHtml.replace('</body>', '<meta http-equiv="refresh" content="0"></body>'), /Meta refresh/);
  rejected(safeHtml.replace('</body>', '<a onclick="x()">x</a></body>'), /event-handler/);
  rejected(safeHtml.replace('</body>', '<a href="javascript:alert(1)">x</a></body>'), /Unsafe URL/);
  rejected(safeHtml.replace('</body>', '<a href="https://example.com">x</a></body>'), /External resources/);
  rejected(safeHtml.replace('</body>', '<img src=https://tracker.example/pixel></body>'), /External resources/);
  rejected(safeHtml.replace('</body>', '<img src="https&colon;//tracker.example/pixel"></body>'), /Character references/);
  rejected(safeHtml.replace('</body>', '<img src="ht\ttps://tracker.example/pixel"></body>'), /Whitespace and control/);
  rejected(safeHtml.replace('</style>', '.x{background:url(https://tracker.example/pixel)}</style>'), /Unsafe CSS/);
  rejected(safeHtml.replace('</body>', '<div style="behavior:url(x)"></div></body>'), /Unsafe CSS/);
  rejected(safeHtml.replace(/<template id="plan-data">[\s\S]*?<\/template>/, ''), /plan-data template/);
  rejected(safeHtml.replace(/<template id="plan-data">[\s\S]*?<\/template>/, '<template id="plan-data">{bad}</template>'), /JSON/);
  rejected(`${safeHtml}${' '.repeat(512 * 1024)}`, /512 KiB/);

  const unsafe = run(build, ['--input', path.join(here, 'fixtures', 'unsafe-plan.json'), '--project', root, '--slug', 'unsafe-plan']);
  const unsafeResult = JSON.parse(unsafe.stdout);
  assert.equal(unsafeResult.ok, true);
  assert.equal(unsafeResult.blockPublish, true);
  const unsafeHtml = await fsp.readFile(unsafeResult.path, 'utf8');
  const unsafePlan = extractPlanData(unsafeHtml);
  assert.equal(unsafePlan.security.blockPublish, true);
  for (const forbidden of ['ghp_abcdefghijklmnopqrstuvwxyz123456', 'syntheticBearerToken1234567890', 'postgres://fakeuser', 'service.example.internal', 'git@github.com', '/Users/newedia/private-project', 'A7d9Kp2Lm4Nq6Rs8Tu0Vw3Xy5Za7Bc9De1Fg3Hi5Jk7Lm9Np2Qr4St6Uv8Wx0Yz2']) {
    assert.equal(unsafeHtml.includes(forbidden), false, `Unsafe value survived: ${forbidden}`);
  }
  const blocked = run(publish, ['--file', unsafeResult.path, '--project', root], 1);
  assert.match(blocked.stderr, /marked local-only/);

  const outside = path.join(root, 'outside.html');
  await fsp.writeFile(outside, safeHtml);
  const outsideResult = run(publish, ['--file', outside, '--project', root], 1);
  assert.match(outsideResult.stderr, /must be a child/);

  const mockDir = path.join(root, 'mock-bin');
  const mockLog = path.join(root, 'postplan.log');
  await fsp.mkdir(mockDir);
  const mock = path.join(mockDir, 'postplan');
  await fsp.writeFile(mock, `#!/usr/bin/env node
import fs from 'node:fs';
const args = process.argv.slice(2);
fs.appendFileSync(process.env.MOCK_LOG, JSON.stringify({ args, apiUrl: process.env.POSTPLAN_API_URL, hasKey: Boolean(process.env.POSTPLAN_API_KEY) }) + '\\n');
if (args[0] === '--version') {
  console.log(process.env.MOCK_VERSION || '0.0.4');
} else if (args[0] === 'whoami') {
  if (process.env.MOCK_AUTH_FAIL === '1') { console.error('Not authenticated'); process.exitCode = 1; }
  else console.log('Authenticated');
} else if (args[0] === 'upload') {
  if (process.env.MOCK_MALFORMED === '1') console.log('Uploaded draft\\nURL: nope');
  else {
    const updated = args.includes('--draft');
    console.log((updated ? 'Updated' : 'Uploaded') + ' draft\\nURL: https://abc123def456.postplan.dev\\nRaw HTML: https://postplan.dev/d/abc123def456/raw\\nDraft ID: abc123def456\\nVersion: ' + (updated ? '2' : '1'));
    console.warn('Warning: synthetic warning');
  }
} else if (args[0] === 'list') {
  console.log(JSON.stringify([{ draftId: 'abc123def456' }]));
} else {
  process.exitCode = 2;
}
`);
  await fsp.chmod(mock, 0o700);
  const baseEnv = {
    ...process.env,
    PATH: `${mockDir}:${process.env.PATH}`,
    MOCK_LOG: mockLog,
    POSTPLAN_API_KEY: 'pp_abcdefghijklmnopqrstuvwxyz1234567890',
    POSTPLAN_API_URL: 'https://attacker.invalid'
  };

  const published = run(publish, ['--file', safeResult.path, '--project', root], 0, baseEnv);
  const payload = JSON.parse(published.stdout);
  assert.deepEqual({ draftId: payload.draftId, version: payload.version, updated: payload.updated }, { draftId: 'abc123def456', version: 2, updated: false });
  assert.equal(payload.url, 'https://abc123def456.postplan.dev/');
  assert.equal(payload.rawUrl, 'https://postplan.dev/d/abc123def456/raw');
  assert.deepEqual(payload.warnings, ['synthetic warning']);
  const calls = (await fsp.readFile(mockLog, 'utf8')).trim().split('\n').map(JSON.parse);
  assert.deepEqual(calls.slice(0, 2).map(call => call.args), [['--version'], ['whoami']]);
  assert.ok(calls.every(call => call.apiUrl === 'https://postplan.dev' && call.hasKey));
  const snapshotPath = path.join(await fsp.realpath(path.join(root, '.claude', 'plans')), '.postplan-upload', 'invoice-export.html');
  assert.equal(calls[2].args[0], 'upload');
  assert.equal(calls[2].args[1], snapshotPath);
  assert.equal(calls[2].args.includes('--draft'), false);
  assert.deepEqual(calls[3].args.slice(0, 2), ['list', '--json']);
  assert.equal(calls[4].args[0], 'upload');
  assert.equal(calls[4].args[1], snapshotPath);
  assert.ok(calls[4].args.includes('--description'));
  assert.equal(calls[4].args[calls[4].args.indexOf('--api-url') + 1], 'https://postplan.dev');
  assert.equal(calls[4].args.includes('--new'), false);
  assert.equal(calls[4].args[calls[4].args.indexOf('--draft') + 1], 'abc123def456');
  assert.equal(fs.existsSync(path.join(root, '.claude', 'plans', '.postplan-upload')), false);

  await fsp.writeFile(mockLog, '');
  const authFailed = run(publish, ['--file', safeResult.path, '--project', root], 1, { ...baseEnv, MOCK_AUTH_FAIL: '1' });
  assert.match(authFailed.stderr, /authentication check failed/);
  const authCalls = (await fsp.readFile(mockLog, 'utf8')).trim().split('\n').map(JSON.parse);
  assert.deepEqual(authCalls.map(call => call.args), [['--version'], ['whoami']]);

  const wrongVersion = run(publish, ['--file', safeResult.path, '--project', root], 1, { ...baseEnv, MOCK_VERSION: '0.0.5' });
  assert.match(wrongVersion.stderr, /Unsupported postplan version/);
  const malformed = run(publish, ['--file', safeResult.path, '--project', root], 1, { ...baseEnv, MOCK_MALFORMED: '1' });
  assert.match(malformed.stderr, /exactly one (?:Draft ID|Raw HTML) field/);

  process.stdout.write(`${JSON.stringify({ ok: true, safePlan: safeResult.path, unsafePlan: unsafeResult.path })}\n`);
} finally {
  await fsp.rm(root, { recursive: true, force: true });
}
