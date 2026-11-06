// Unit tests for pi/extensions/role-reply.ts and orch-wake.ts, with a fake
// Pi API. No model is called. Run: node test/async-extensions.mjs
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "../pi/extensions");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "async-ext-"));
let n = 0;
let failed = 0;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function test(name, fn) {
  try {
    await fn();
    console.log(`PASS: ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL: ${name}\n${e.stack}`);
  }
}

// Load an extension with this environment. Each load is a new module.
async function load(file, env) {
  const state = fs.mkdtempSync(path.join(tmp, "state-"));
  for (const k of Object.keys(process.env)) if (k.startsWith("AGENT_ROLE")) delete process.env[k];
  Object.assign(process.env, { AGENT_ROLES_STATE_DIR: state }, env);
  const mod = await import(`${root}/${file}?case=${n++}`);
  const handlers = {};
  const sent = [];
  const pi = {
    on: (ev, fn) => (handlers[ev] = fn),
    sendMessage: (msg, opts) => sent.push({ msg, opts }),
  };
  mod.default(pi);
  return { mod, handlers, sent, state };
}
const assistant = (text) => ({ role: "assistant", content: [{ type: "text", text }] });
const pendingFile = (state, prefix, name, startedAt = new Date().toISOString()) => {
  const f = path.join(state, "pending", prefix, `${name}.json`);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, JSON.stringify({ name, started_at: startedAt }));
  return f;
};
const taskEnv = { AGENT_ROLE_NAME: "w4-t1-dev", AGENT_ROLE_PREFIX: "w4-t1", AGENT_ROLE_MODE: "task" };

// --- role-reply -----------------------------------------------------------
await test("parseStatus reads the last line", async () => {
  const { mod } = await load("role-reply.ts", taskEnv);
  assert.deepEqual(mod.parseStatus("a\nSTATUS: done\n"), { status: "done", reason: "" });
  assert.deepEqual(mod.parseStatus("STATUS: blocked - need a key"), { status: "blocked", reason: "need a key" });
  assert.deepEqual(mod.parseStatus("x\nSTATUS: failed - tests red\n\n"), { status: "failed", reason: "tests red" });
  assert.equal(mod.parseStatus("STATUS: done\nand more text").status, "unknown");
  assert.equal(mod.parseStatus("STATUS: maybe").status, "unknown");
  assert.equal(mod.parseStatus("").status, "unknown");
});

await test("a task reply writes the files and removes the marker", async () => {
  const { handlers, state } = await load("role-reply.ts", taskEnv);
  const marker = pendingFile(state, "w4-t1", "w4-t1-dev");
  await handlers.agent_end({ messages: [{ role: "user", content: [] }, assistant("Did it.\nSTATUS: done")] });
  await handlers.agent_settled({ aborted: false });
  const dir = path.join(state, "replies", "w4-t1");
  assert.equal(fs.readFileSync(path.join(dir, "w4-t1-dev.md"), "utf8"), "Did it.\nSTATUS: done\n");
  const meta = JSON.parse(fs.readFileSync(path.join(dir, "w4-t1-dev.json"), "utf8"));
  assert.deepEqual([meta.name, meta.status, meta.reason], ["w4-t1-dev", "done", ""]);
  assert.ok(Date.parse(meta.ended_at) > 0);
  assert.ok(!fs.existsSync(marker));
  assert.deepEqual(fs.readdirSync(dir).sort(), ["w4-t1-dev.json", "w4-t1-dev.md"], "no temp files left");
});

await test("the last assistant text of several runs wins", async () => {
  const { handlers, state } = await load("role-reply.ts", taskEnv);
  pendingFile(state, "w4-t1", "w4-t1-dev");
  await handlers.agent_end({ messages: [assistant("first")] });
  await handlers.agent_end({ messages: [assistant("second\nSTATUS: failed - boom")] });
  await handlers.agent_settled({ aborted: false });
  const meta = JSON.parse(fs.readFileSync(path.join(state, "replies/w4-t1/w4-t1-dev.json"), "utf8"));
  assert.deepEqual([meta.status, meta.reason], ["failed", "boom"]);
});

await test("an aborted task is unknown with reason aborted", async () => {
  const { handlers, state } = await load("role-reply.ts", taskEnv);
  pendingFile(state, "w4-t1", "w4-t1-dev");
  await handlers.agent_end({ messages: [assistant("half\nSTATUS: done")] });
  await handlers.agent_settled({ aborted: true });
  const meta = JSON.parse(fs.readFileSync(path.join(state, "replies/w4-t1/w4-t1-dev.json"), "utf8"));
  assert.deepEqual([meta.status, meta.reason], ["unknown", "aborted"]);
});

await test("no marker: a person typed, so nothing is written", async () => {
  const { handlers, state } = await load("role-reply.ts", taskEnv);
  await handlers.agent_end({ messages: [assistant("hi\nSTATUS: done")] });
  await handlers.agent_settled({ aborted: false });
  assert.ok(!fs.existsSync(path.join(state, "replies")));
});

await test("a chat agent registers nothing", async () => {
  const { handlers } = await load("role-reply.ts", { ...taskEnv, AGENT_ROLE_MODE: "chat" });
  assert.deepEqual(Object.keys(handlers), []);
});

await test("a second task writes a second reply and keeps no old text", async () => {
  const { handlers, state } = await load("role-reply.ts", taskEnv);
  pendingFile(state, "w4-t1", "w4-t1-dev");
  await handlers.agent_end({ messages: [assistant("one\nSTATUS: done")] });
  await handlers.agent_settled({ aborted: false });
  pendingFile(state, "w4-t1", "w4-t1-dev");
  await handlers.agent_end({ messages: [] });
  await handlers.agent_settled({ aborted: false });
  assert.equal(fs.readFileSync(path.join(state, "replies/w4-t1/w4-t1-dev.md"), "utf8"), "(no reply text)\n");
});

// --- orch-wake ------------------------------------------------------------
const reply = (state, prefix, name, status, reason = "", text = "reply text\n") => {
  const dir = path.join(state, "replies", prefix);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `${name}.md`), text);
  fs.writeFileSync(path.join(dir, `${name}.json`), JSON.stringify({ name, status, reason, ended_at: "x" }));
};
const until = async (cond, ms = 4000) => {
  const end = Date.now() + ms;
  while (Date.now() < end && !cond()) await sleep(50);
};

await test("orch-wake sets AGENT_ROLES_ASYNC and wakes once for a reply", async () => {
  const { handlers, sent, state } = await load("orch-wake.ts", { AGENT_ROLE_PREFIX: "w4-t1" });
  assert.equal(process.env.AGENT_ROLES_ASYNC, "1");
  await handlers.session_start();
  reply(state, "w4-t1", "w4-t1-dev", "blocked", "need a key");
  await until(() => sent.length > 0);
  await sleep(2500); // a second scan must not wake again
  assert.equal(sent.length, 1);
  const { msg, opts } = sent[0];
  assert.deepEqual(opts, { triggerTurn: true, deliverAs: "followUp" });
  assert.match(msg.content, /w4-t1-dev finished.*STATUS blocked \(need a key\)/);
  assert.ok(msg.content.includes(path.join(state, "replies/w4-t1/w4-t1-dev.md")));
  assert.ok(fs.existsSync(path.join(state, "handled/w4-t1/w4-t1-dev.json")));
  assert.ok(!fs.existsSync(path.join(state, "replies/w4-t1/w4-t1-dev.json")));
  assert.ok(fs.existsSync(path.join(state, "replies/w4-t1/w4-t1-dev.md")), "reply text stays");
  await handlers.session_shutdown();
});

await test("two replies wake twice, in name order", async () => {
  const { handlers, sent, state } = await load("orch-wake.ts", { AGENT_ROLE_PREFIX: "w4-t1" });
  await handlers.session_start();
  reply(state, "w4-t1", "w4-t1-qa", "done");
  reply(state, "w4-t1", "w4-t1-dev", "done");
  await until(() => sent.length >= 2);
  assert.equal(sent.length, 2);
  assert.match(sent[0].msg.content, /w4-t1-dev/);
  assert.match(sent[1].msg.content, /w4-t1-qa/);
  await handlers.session_shutdown();
});

await test("replies that came before the session started wake it at start", async () => {
  const { handlers, sent, state } = await load("orch-wake.ts", { AGENT_ROLE_PREFIX: "w4-t1" });
  reply(state, "w4-t1", "w4-t1-dev", "done");
  await handlers.session_start();
  assert.equal(sent.length, 1);
  await handlers.session_shutdown();
});

await test("replies of another tab do not wake this one", async () => {
  const { handlers, sent, state } = await load("orch-wake.ts", { AGENT_ROLE_PREFIX: "w4-t1" });
  await handlers.session_start();
  reply(state, "w9-t9", "w9-t9-dev", "done");
  await sleep(2500);
  assert.equal(sent.length, 0);
  await handlers.session_shutdown();
});

await test("the prefix comes from HERDR_TAB_ID when AGENT_ROLE_PREFIX is not set", async () => {
  process.env.HERDR_TAB_ID = "wT:t2";
  const { handlers, sent, state } = await load("orch-wake.ts", {});
  reply(state, "wt-t2", "wt-t2-dev", "done");
  await handlers.session_start();
  assert.equal(sent.length, 1);
  await handlers.session_shutdown();
  delete process.env.HERDR_TAB_ID;
});

await test("the watchdog warns once about an old pending task", async () => {
  const { handlers, sent, state } = await load("orch-wake.ts", {
    AGENT_ROLE_PREFIX: "w4-t1",
    AGENT_ROLES_WATCHDOG_MS: "4000",
  });
  pendingFile(state, "w4-t1", "w4-t1-dev", new Date(Date.now() - 10000).toISOString());
  pendingFile(state, "w4-t1", "w4-t1-qa"); // new: no warning yet
  await handlers.session_start();
  await until(() => sent.length > 0);
  await sleep(1600); // two more checks: no second warning for dev, none for qa
  assert.equal(sent.length, 1);
  assert.match(sent[0].msg.content, /w4-t1-dev has had no reply/);
  assert.equal(sent[0].msg.customType, "agent-watchdog");
  await handlers.session_shutdown();
});

await test("no prefix: the extension does nothing", async () => {
  delete process.env.HERDR_TAB_ID;
  const { handlers } = await load("orch-wake.ts", {});
  assert.deepEqual(Object.keys(handlers), []);
});

fs.rmSync(tmp, { recursive: true, force: true });
if (failed) {
  console.log(`${failed} extension test(s) failed`);
  process.exit(1);
}
console.log("All async extension tests passed");
