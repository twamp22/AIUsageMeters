#!/usr/bin/env node
// Spawns codex in a PTY from HOME (auto-trusts dir), sends /status after
// startup, waits for the panel to render, dumps raw + JSON to stdout.

const pty = require('node-pty');
const fs = require('fs');
const path = require('path');
const STRIP = /\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07]*\x07/g;

// On Windows the npm shim (`codex.cmd`) can't be spawned by node-pty directly,
// so point at the real codex.exe. Override with the CODEX_EXE env var if yours
// lives elsewhere.
const CODEX_EXE = process.env.CODEX_EXE
  || (process.platform === 'win32'
        ? path.join(process.env.APPDATA || '', 'npm', 'node_modules', '@openai', 'codex', 'node_modules', '@openai', 'codex-win32-x64', 'vendor', 'x86_64-pc-windows-msvc', 'codex', 'codex.exe')
        : 'codex');

const term = pty.spawn(CODEX_EXE, [], {
  name: 'xterm-256color',
  cols: 160,
  rows: 50,
  cwd: process.env.USERPROFILE || process.env.HOME || process.cwd(),
  env: process.env,
});

let buf = '';
let trusted = false;
let sent = false;

const bail = (msg, code) => {
  try { fs.writeFileSync(path.join(__dirname, 'scrape-codex-debug.txt'), buf); } catch {}
  console.error(msg);
  try { term.kill(); } catch {}
  process.exit(code);
};

const timeout = setTimeout(() => bail('timeout', 2), 45000);

term.onData((data) => {
  buf += data;

  if (!trusted && /trust the contents/i.test(buf.replace(STRIP, ''))) {
    trusted = true;
    setTimeout(() => term.write('1\r'), 400);
    return;
  }
});

// Fire /status 5s after spawn, then capture 4s after that.
setTimeout(() => {
  sent = true;
  // type slowly so the slash-command popup can catch up, then hit Enter twice.
  const s = '/status';
  for (let i = 0; i < s.length; i++) setTimeout(() => term.write(s[i]), i * 60);
  setTimeout(() => term.write('\r'), s.length * 60 + 400);
  setTimeout(() => term.write('\r'), s.length * 60 + 900);
}, 9000);
setTimeout(() => {
  const out = buf.replace(STRIP, '');
  fs.writeFileSync(path.join(__dirname, 'scrape-codex-debug.txt'), out);
  // Codex reports "NN% left (resets TIMESTAMP)"
  const grab = (labelRe) => {
    const m = out.match(labelRe);
    if (!m) return null;
    const tail = out.slice(m.index, m.index + 240);
    const pct = tail.match(/(\d{1,3})\s*%\s*left/i);
    const rst = tail.match(/resets?\s+([^\r\n│)]+?)\s*\)/i);
    return {
      pct: pct ? 100 - +pct[1] : null,   // convert % left → % used
      reset: rst ? rst[1].trim() : null,
    };
  };
  const payload = {
    session: grab(/5h\s*limit/i),
    weekly: grab(/Weekly\s*limit/i),
  };
  process.stdout.write(JSON.stringify(payload));
  clearTimeout(timeout);
  try { term.kill(); } catch {}
  process.exit(0);
}, 16000);

term.onExit(() => {
  if (!sent) bail('codex exited before /status was sent', 3);
});
