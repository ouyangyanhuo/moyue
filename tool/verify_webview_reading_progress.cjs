// Run with Node to exercise the injected script against deterministic DOM/timers.
// This does not replace Android/iOS platform-view integration testing.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dart = fs.readFileSync(path.join(__dirname,
  '../lib/features/reader/webview_reading_progress.dart'), 'utf8');
const template = dart.slice(dart.indexOf("'''\n") + 4, dart.lastIndexOf("'''"));

function page(initial, layout = 'same') {
  let now = 0, serial = 0;
  const timers = new Map(), listeners = new Map(), messages = [];
  const on = (name, fn) => {
    const items = listeners.get(name) || new Set();
    items.add(fn); listeners.set(name, items);
  };
  const off = (name, fn) => listeners.get(name)?.delete(fn);
  const fire = name => [...(listeners.get(name) || [])].forEach(fn => fn());
  const env = {
    performance: {now: () => now}, innerHeight: 500, scrollY: 0, scrollX: 0,
    document: {documentElement: {scrollHeight: 1500}, body: {scrollHeight: 1500},
      addEventListener: on, removeEventListener: off, hidden: false},
    addEventListener: on, removeEventListener: off,
    setTimeout(fn, delay) {const id = ++serial; timers.set(id, {fn, at: now + delay}); return id;},
    clearTimeout(id) {timers.delete(id);},
    channel: {postMessage(message) {messages.push(JSON.parse(message));}},
  };
  env.window = env;
  env.scrollTo = ({top}) => {if (env.scrollY !== top) {env.scrollY = top; fire('scroll');}};
  const context = vm.createContext(env);
  const script = template
    .replace('${jsonEncode(channel)}', JSON.stringify('channel'))
    .replace("${initial?.encode() ?? 'null'}", JSON.stringify(initial))
    .replace('${jsonEncode(layout)}', JSON.stringify(layout));
  vm.runInContext(script, context);
  function advance(ms) {
    const end = now + ms;
    while (true) {
      const next = [...timers.entries()].filter(([, t]) => t.at <= end)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      now = next[1].at; timers.delete(next[0]); next[1].fn();
    }
    now = end;
  }
  return {env, fire, advance, messages, timers, context, script};
}

const initial = {offset: 600, extent: 1000, layout: 'same'};
let p = page(initial);
assert.equal(p.env.scrollY, 600);
p.advance(1800);
assert.equal(p.messages.length, 0, 'Restoration must not save transient positions');
assert.equal(p.timers.size, 0, 'Restoration must stop scheduling work');

p = page(initial);
p.fire('touchstart'); p.env.scrollY = 250; p.fire('scroll');
p.advance(2000);
assert.equal(p.env.scrollY, 250, 'User scroll cancels restoration');
assert.equal(p.messages.at(-1).offset, 250);

p = page({...initial, extent: 2000}, 'different');
assert.equal(p.env.scrollY, 300, 'Changed layout uses relative progress');
p.env.document.documentElement.scrollHeight = 2500;
p.env.document.body.scrollHeight = 2500;
p.advance(120);
assert.equal(p.env.scrollY, 600, 'Delayed document height is considered');

p = page(null);
for (let i = 0; i < 60; i++) {p.env.scrollY = i; p.fire('scroll');}
assert.equal(p.messages.length, 0);
p.advance(200);
assert.equal(p.messages.length, 1, 'Scroll reports are throttled');
assert.equal(p.messages[0].offset, 59);
p.env.scrollY = 70; p.fire('scroll'); p.fire('scrollend');
assert.equal(p.messages.at(-1).offset, 70, 'Scroll end reports immediately');
assert.equal(p.env.__moyueReadingSnapshot().offset, 70);
vm.runInContext(p.script, p.context);
p.env.scrollY = 85; p.fire('scroll'); p.advance(200);
assert.equal(p.messages.length, 3, 'Reinstall removes old observers');
p.env.__moyueReadingCleanup();
assert.equal(p.timers.size, 0);
console.log('WebView reading-progress script: all checks passed.');
