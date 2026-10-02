import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { closeSync, mkdirSync, mkdtempSync, openSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
if (args.length !== 2 || args[0] !== '--app-root') {
  console.error('usage: node tests/feed/bundle.mjs --app-root <consumer-checkout>');
  process.exit(2);
}
const appRoot = resolve(args[1]);
const evidenceRoot = join(root, '.build/real-tests/feed');
mkdirSync(evidenceRoot, { recursive: true });
const evidence = mkdtempSync(join(evidenceRoot, 'run-'));
const report = { started_at: new Date().toISOString(), app_root: appRoot, commands: [], result: 'blocked' };
const environment = { ...process.env, WISENT_INSTALL_AFTER_BUILD: '0', WISENT_RESTART_AFTER_BUILD: '0' };
delete environment.WISENT_UPDATE_FEED_URL;
delete environment.SKARBIEC_UPDATE_FEED_URL;

function run(executable, arguments_, cwd, env = environment) {
  const index = report.commands.length;
  const stdoutPath = join(evidence, `${index}.stdout.log`);
  const stderrPath = join(evidence, `${index}.stderr.log`);
  const stdout = openSync(stdoutPath, 'w', 0o600);
  const stderr = openSync(stderrPath, 'w', 0o600);
  let child;
  try {
    child = spawnSync(executable, arguments_, { cwd, env, stdio: ['ignore', stdout, stderr] });
  } finally {
    closeSync(stdout);
    closeSync(stderr);
  }
  const result = { executable, arguments: arguments_, cwd, exit_status: child.status,
    signal: child.signal, error: child.error?.message, stdout: stdoutPath, stderr: stderrPath };
  report.commands.push(result);
  return { ...result, output: readFileSync(stdoutPath, 'utf8'), errors: readFileSync(stderrPath, 'utf8') };
}
function success(result) {
  assert.equal(result.exit_status, 0, `${result.executable} failed: ${result.errors || result.error || result.signal}`);
  return result.output.trim();
}

try {
  report.revision = success(run('git', ['rev-parse', 'HEAD'], root));
  report.consumer_revision = success(run('git', ['rev-parse', 'HEAD'], appRoot));
  report.consumer_working_diff = success(run('git', ['diff', 'HEAD', '--'], appRoot));
  report.test_sha256 = createHash('sha256').update(readFileSync(fileURLToPath(import.meta.url))).digest('hex');
  const manifest = JSON.parse(readFileSync(join(appRoot, '.wisent-desktop-release.json'), 'utf8'));
  const release = JSON.parse(readFileSync(join(appRoot, '.wisent-release.json'), 'utf8'));
  assert.match(release.product, /^[a-z0-9-]+$/);
  assert.equal(typeof manifest.build_command, 'string');
  const plist = resolve(appRoot, manifest.bundle_path, 'Contents/Info.plist');
  assert.ok(plist.startsWith(`${join(appRoot, '.build')}/`), 'the bundle must be inside the consumer ignored build directory');
  report.product = release.product;
  const feed = success(run('stado', ['web', 'origin', 'url', '/api/release/appcast', '--query', `product=${release.product}`], appRoot));
  assert.equal(new URL(feed).protocol, 'https:');
  report.resolved_feed = feed;
  const response = await fetch(feed);
  const appcast = await response.text();
  writeFileSync(join(evidence, 'appcast.xml'), appcast, { mode: 0o600 });
  report.appcast = { requested_url: feed, final_url: response.url, status: response.status };
  assert.equal(response.status, 200, 'the resolved feed must be readable');
  assert.match(appcast, /<rss\b/);
  assert.match(appcast, /<channel\b/);

  // Execute the product's declared build operation in its sole checkout.
  // Each desktop manifest disables installation; the shared flags also disable restart.
  report.build_command = manifest.build_command;
  success(run('/bin/sh', ['-c', manifest.build_command], appRoot));
  const observed = success(run('/usr/bin/plutil', ['-extract', 'SUFeedURL', 'raw', '-o', '-', plist], appRoot));
  assert.equal(observed, feed, 'the built app must use the declared Stado origin');
  report.bundle_feed = observed;

  const invalid = run('/bin/sh', ['-c', manifest.build_command], appRoot,
    { ...environment, WISENT_UPDATE_FEED_URL: 'http://example.invalid/appcast' });
  assert.notEqual(invalid.exit_status, 0, 'an insecure feed must refuse the build');
  assert.notEqual(invalid.exit_status, null, 'a killed build does not prove a feed refusal');
  assert.match(`${invalid.output}\n${invalid.errors}`, /(?:feed.*HTTPS|HTTPS.*feed)/i,
    'the refusal must identify the update feed, not an unrelated build failure');
  report.insecure_feed_refused = true;

  // Leave a valid source bundle, not the staging output of the refused build.
  success(run('/bin/sh', ['-c', manifest.build_command], appRoot));
  report.final_bundle_feed = success(run('/usr/bin/plutil', ['-extract', 'SUFeedURL', 'raw', '-o', '-', plist], appRoot));
  assert.equal(report.final_bundle_feed, feed);
  report.result = 'passed';
} catch (error) {
  report.error = error.stack ?? String(error);
  process.exitCode = 1;
} finally {
  report.finished_at = new Date().toISOString();
  writeFileSync(join(evidence, 'report.json'), `${JSON.stringify(report, null, 2)}\n`, { mode: 0o600 });
  console.log(`${report.result}: ${join(evidence, 'report.json')}`);
}
