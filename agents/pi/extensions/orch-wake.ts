// Orchestrator side of async replies. Loaded by hw/ht for a Pi orchestrator.
//
// Watches <state>/replies/<prefix>/ for reply files from role agents. Each
// new reply wakes the orchestrator with a short message that names the agent,
// its status, and the reply file. The orchestrator reads the file. A watchdog
// warns when a task stays pending for too long.
//
// Environment:
//   AGENT_ROLE_PREFIX      tab prefix (default: from HERDR_TAB_ID, w4:t1 -> w4-t1)
//   AGENT_ROLES_STATE_DIR  state root (default ~/.local/state/agent-roles)
//   AGENT_ROLES_WATCHDOG_MS  pending limit in ms (default 15 minutes)
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const prefix =
  process.env.AGENT_ROLE_PREFIX ??
  (process.env.HERDR_TAB_ID ?? "").toLowerCase().replace(/:/g, "-");
const stateRoot =
  process.env.AGENT_ROLES_STATE_DIR ??
  path.join(process.env.XDG_STATE_HOME ?? path.join(os.homedir(), ".local", "state"), "agent-roles");
const watchdogMs = Number(process.env.AGENT_ROLES_WATCHDOG_MS ?? 15 * 60 * 1000);

export default function (pi: ExtensionAPI) {
  if (!prefix) return;
  // Tell agent-role (run by the bash tool, which inherits this environment)
  // that a reply wakes this session. It then writes pending markers and tells
  // the orchestrator to end its turn instead of waiting.
  process.env.AGENT_ROLES_ASYNC = "1";
  const repliesDir = path.join(stateRoot, "replies", prefix);
  const handledDir = path.join(stateRoot, "handled", prefix);
  const pendingDir = path.join(stateRoot, "pending", prefix);
  const alerted = new Set<string>();
  let timers: ReturnType<typeof setInterval>[] = [];
  let watcher: fs.FSWatcher | undefined;

  const wake = (content: string, kind: string) =>
    // followUp: wait for the current turn and its tool calls. Idle: start now.
    pi.sendMessage(
      { customType: kind, content, display: true },
      { triggerTurn: true, deliverAs: "followUp" },
    );

  function scanReplies() {
    let files: string[] = [];
    try {
      files = fs.readdirSync(repliesDir).filter((f) => f.endsWith(".json")).sort();
    } catch {
      return;
    }
    for (const f of files) {
      const meta = path.join(repliesDir, f);
      let info: any;
      try {
        info = JSON.parse(fs.readFileSync(meta, "utf8"));
      } catch {
        continue; // half-written is impossible (atomic), but be safe
      }
      // Move the marker first. If this fails, do not wake: no double wake.
      fs.mkdirSync(handledDir, { recursive: true });
      try {
        fs.renameSync(meta, path.join(handledDir, f));
      } catch {
        continue;
      }
      const md = path.join(repliesDir, f.replace(/\.json$/, ".md"));
      const why = info.reason ? ` (${info.reason})` : "";
      wake(
        `Role agent ${info.name} finished its task: STATUS ${info.status}${why}. ` +
          `Its reply is in ${md}. Read that file now. Do not read the pane.`,
        "agent-reply",
      );
    }
  }

  function scanPending() {
    let files: string[] = [];
    try {
      files = fs.readdirSync(pendingDir).filter((f) => f.endsWith(".json"));
    } catch {
      return;
    }
    for (const f of files) {
      if (alerted.has(f)) continue;
      try {
        const info = JSON.parse(fs.readFileSync(path.join(pendingDir, f), "utf8"));
        const age = Date.now() - Date.parse(info.started_at);
        if (age < watchdogMs) continue;
        alerted.add(f);
        wake(
          `Role agent ${info.name} has had no reply for ${Math.round(age / 60000)} minutes. ` +
            `Check it: herdr agent get ${info.name}. Then ask the user what to do.`,
          "agent-watchdog",
        );
      } catch {
        /* ignore */
      }
    }
  }

  pi.on("session_start", async () => {
    fs.mkdirSync(repliesDir, { recursive: true });
    scanReplies(); // replies that came while this session was closed
    try {
      watcher = fs.watch(repliesDir, () => scanReplies());
    } catch {
      /* the poll below still works */
    }
    // The poll is a safety net: fs.watch can miss events.
    timers.push(setInterval(scanReplies, 2000).unref());
    timers.push(setInterval(scanPending, Math.min(60_000, Math.max(500, watchdogMs / 4))).unref());
  });

  pi.on("session_shutdown", async () => {
    watcher?.close();
    timers.forEach(clearInterval);
    timers = [];
  });
}
