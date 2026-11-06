// Role side of async replies. Loaded by agent-role in task mode only.
//
// When a task ends and the agent has settled, write its last reply to a file
// and remove the pending marker. The orchestrator's orch-wake extension reads
// the file. Chat agents (AGENT_ROLE_MODE=chat) and other Pi sessions do
// nothing.
//
// Environment (set by agent-role):
//   AGENT_ROLE_NAME    agent name, for example w4-t1-dev
//   AGENT_ROLE_PREFIX  tab prefix, for example w4-t1
//   AGENT_ROLE_MODE    task or chat
//   AGENT_ROLES_STATE_DIR  state root (default ~/.local/state/agent-roles)
//
// Files, all in <state>/<kind>/<prefix>/:
//   pending/<name>.json   {name, started_at}      written by agent-role --prompt
//   replies/<name>.md     the reply text
//   replies/<name>.json   {name, status, reason, ended_at}, written last
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const name = process.env.AGENT_ROLE_NAME ?? "";
const prefix = process.env.AGENT_ROLE_PREFIX ?? "";
const mode = process.env.AGENT_ROLE_MODE ?? "";
const stateRoot =
  process.env.AGENT_ROLES_STATE_DIR ??
  path.join(process.env.XDG_STATE_HOME ?? path.join(os.homedir(), ".local", "state"), "agent-roles");

export type Status = "done" | "blocked" | "failed" | "unknown";

// The last non-empty line decides. "STATUS: done", or "STATUS: blocked - why".
export function parseStatus(text: string): { status: Status; reason: string } {
  const last = text.trimEnd().split("\n").pop()?.trim() ?? "";
  const m = /^STATUS:\s*(done|blocked|failed)(?:\s+-\s+(.*))?$/.exec(last);
  return m ? { status: m[1] as Status, reason: m[2] ?? "" } : { status: "unknown", reason: "no STATUS line" };
}

// Write a file so that a reader sees all of it or none of it.
export function writeAtomic(file: string, data: string): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp-${process.pid}`;
  fs.writeFileSync(tmp, data);
  fs.renameSync(tmp, file);
}

function lastAssistantText(messages: any[]): string | undefined {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m?.role !== "assistant") continue;
    const parts = Array.isArray(m.content) ? m.content : [];
    const text = parts
      .filter((p: any) => p?.type === "text")
      .map((p: any) => p.text)
      .join("\n")
      .trim();
    if (text) return text;
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  if (mode !== "task" || !name || !prefix) return;

  const pending = path.join(stateRoot, "pending", prefix, `${name}.json`);
  const replyMd = path.join(stateRoot, "replies", prefix, `${name}.md`);
  const replyJson = path.join(stateRoot, "replies", prefix, `${name}.json`);
  let text = "";

  // A run can be followed by retries or queued work. Keep the latest text.
  pi.on("agent_end", async (event: any) => {
    text = lastAssistantText(event.messages ?? []) ?? text;
  });

  pi.on("agent_settled", async (event: any) => {
    // No marker: a person typed in the pane. Nobody waits for a reply.
    if (!fs.existsSync(pending)) return;
    const parsed = event.aborted
      ? { status: "unknown" as Status, reason: "aborted" }
      : parseStatus(text);
    writeAtomic(replyMd, text ? `${text}\n` : "(no reply text)\n");
    writeAtomic(
      replyJson,
      JSON.stringify({ name, ...parsed, ended_at: new Date().toISOString() }) + "\n",
    );
    fs.rmSync(pending, { force: true });
    text = "";
  });
}
