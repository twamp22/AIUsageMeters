#!/usr/bin/env node
// Spawns `claude` in a PTY, sends `/usage`, captures the rendered panel,
// strips ANSI, parses percents + reset times, and prints JSON to stdout.
//
// Output shape: {"session":{"pct":36,"reset":"1m"},"weeklyAll":{...},"weeklySonnet":{...}}

const pty = require('node-pty');
const fs = require('fs');
const path = require('path');
const STRIP = /\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07]*\x07/g;

const term = pty.spawn(process.platform === 'win32' ? 'claude.exe' : 'claude', [], {
  name: 'xterm-256color',
  cols: 160,
  rows: 40,
  cwd: process.cwd(),
  env: process.env,
});

let buf = '';
let sentUsage = false;
let fireTimer = null;
let captureTimer = null;

const bail = (msg, code) => {
  try { fs.writeFileSync(path.join(__dirname, 'scrape-debug.txt'), buf); } catch {}
  console.error(msg);
  try { term.kill(); } catch {}
  process.exit(code);
};

const timeout = setTimeout(() => bail('timeout', 2), 45000);

term.onData((data) => {
  buf += data;

  if (!sentUsage && !fireTimer) {
    fireTimer = setTimeout(() => {
      sentUsage = true;
      term.write('/usage\r');
    }, 4000);
  }

  const clean = buf.replace(STRIP, '');
  if (sentUsage && /Current session|Current week/i.test(clean) && !captureTimer) {
    captureTimer = setTimeout(() => {
      const out = buf.replace(STRIP, '');
      const grab = (labelRe) => {
        const m = out.match(labelRe);
        if (!m) return null;
        const tail = out.slice(m.index, m.index + 220);
        const pct = tail.match(/(\d{1,3})\s*%/);
        const rst = tail.match(/Rese[ts]+s?\s*([^\r\n│]+?)(?:\s*\(|\s*$|Current|Extra)/i);
        return {
          pct: pct ? +pct[1] : null,
          reset: rst ? rst[1].trim() : null,
        };
      };
      const data = {
        session: grab(/Current session/i),
        weeklyAll: grab(/Current week\s*\(all models\)/i),
        weeklySonnet: grab(/Current week\s*\(Sonnet[^)]*\)/i),
      };
      process.stdout.write(JSON.stringify(data));
      clearTimeout(timeout);
      try { term.kill(); } catch {}
      process.exit(0);
    }, 1500);
  }
});

term.onExit(() => {
  if (!sentUsage) bail('claude exited before /usage was sent', 3);
});
