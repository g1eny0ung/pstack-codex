#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";

const HISTORY_METHOD = "thread/turns/list";

export async function readThreadHistory(request, {
  threadId,
  pageSize = 20,
  maxPages = 1000,
} = {}) {
  if (typeof threadId !== "string" || !threadId.trim()) {
    throw new Error("A thread ID is required; pass --thread-id or set CODEX_THREAD_ID.");
  }
  const turns = new Map();
  const seenCursors = new Set();
  const warnings = [];
  let cursor;
  let pages = 0;
  let complete = false;
  let error;

  while (pages < maxPages) {
    let page;
    try {
      page = await request(HISTORY_METHOD, {
        threadId,
        itemsView: "full",
        sortDirection: "asc",
        limit: pageSize,
        ...(cursor === undefined ? {} : { cursor }),
      });
      if (!page || !Array.isArray(page.data)) {
        throw new Error("Invalid history response: expected a data array.");
      }
      if (!(page.nextCursor === null || typeof page.nextCursor === "string")) {
        throw new Error("Invalid history response: nextCursor is missing or invalid.");
      }
    } catch (cause) {
      error = `${HISTORY_METHOD}: ${cause instanceof Error ? cause.message : String(cause)}`;
      warnings.push("History is incomplete because a page could not be read.");
      break;
    }
    pages += 1;
    for (const turn of page.data) {
      if (!turn || typeof turn.id !== "string" || !Array.isArray(turn.items)) {
        error = "Invalid turn: expected an id and an items array.";
        warnings.push("History is incomplete because a turn could not be decoded.");
        break;
      }
      if (turn.itemsView !== undefined && turn.itemsView !== "full") {
        warnings.push(`Turn ${turn.id} returned ${turn.itemsView} items; full history is unavailable for this turn.`);
      }
      if (turn.items.length === 0) {
        warnings.push(`Turn ${turn.id} has no persisted items; no messages or tool evidence are available for it.`);
      }
      if (turn.status === "inProgress") {
        warnings.push(`Turn ${turn.id} is still in progress; this is a snapshot of persisted items.`);
      }
      for (const item of turn.items) {
        if (!item || typeof item !== "object") {
          warnings.push(`Turn ${turn.id} contains an invalid item; it is preserved without interpretation.`);
          continue;
        }
        const missingOutput =
          (item.type === "commandExecution" && item.aggregatedOutput == null) ||
          (item.type === "dynamicToolCall" && item.contentItems == null) ||
          (item.type === "mcpToolCall" && item.result == null && item.error == null);
        if (missingOutput) warnings.push(`Turn ${turn.id}, item ${item.id ?? "unknown"} has no persisted tool output.`);
        const output = JSON.stringify(item.aggregatedOutput ?? item.result ?? item.contentItems ?? "");
        if (/(?:output.{0,20}truncated|truncated.{0,20}output|\d+ (?:tokens|characters) truncated)/i.test(output)) {
          warnings.push(`Turn ${turn.id}, item ${item.id ?? "unknown"} reports truncated tool output; the saved text is preserved.`);
        }
      }
      turns.set(turn.id, turn);
    }
    if (error) break;
    cursor = page.nextCursor;
    if (cursor === null) {
      complete = warnings.length === 0;
      break;
    }
    if (seenCursors.has(cursor)) {
      error = "History pagination returned a repeated cursor.";
      warnings.push("History is incomplete; pagination stopped to avoid repeating pages.");
      break;
    }
    seenCursors.add(cursor);
  }
  if (cursor !== null && pages === maxPages && !error) {
    warnings.push(`History is truncated at the ${maxPages}-page limit; use a larger --max-pages value.`);
  }
  if (turns.size === 0 && !error) {
    warnings.push("No persisted turns were returned for this thread.");
    complete = false;
  }
  return {
    threadId,
    source: "Codex App Server persisted history",
    requestedItemsView: "full",
    complete,
    limitation: "Full means every item available in persisted history. Tool output already truncated or omitted before persistence cannot be recovered. Turn and item IDs, tool calls, and results are preserved as returned by the server.",
    pages,
    nextCursor: cursor ?? null,
    warnings: [...new Set(warnings)],
    ...(error ? { error } : {}),
    turns: [...turns.values()],
  };
}

export function createAppServerClient({ timeoutMs = 30000, command = "codex" } = {}) {
  const child = spawn(command, ["app-server", "--listen", "stdio://"], {
    stdio: ["pipe", "pipe", "pipe"],
  });
  const input = createInterface({ input: child.stdout });
  const pending = new Map();
  let serial = 0;
  let failure;
  let stderr = "";
  let closed = false;

  function fail(cause) {
    failure = cause instanceof Error ? cause : new Error(String(cause));
    for (const { reject, timer } of pending.values()) {
      clearTimeout(timer);
      reject(failure);
    }
    pending.clear();
  }
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => { stderr = (stderr + chunk).slice(-4000); });
  child.on("error", (cause) => fail(new Error(`Cannot start Codex App Server: ${cause.message}`)));
  child.stdin.on("error", (cause) => fail(new Error(`Codex App Server input failed: ${cause.message}`)));
  child.on("close", (code, signal) => {
    closed = true;
    fail(new Error(`Codex App Server exited (${signal ?? code}).${stderr ? ` ${stderr.trim()}` : ""}`));
  });
  input.on("line", (line) => {
    if (!line.trim()) return;
    let message;
    try { message = JSON.parse(line); }
    catch { fail(new Error("Codex App Server emitted an invalid JSON message.")); return; }
    if (!message || typeof message !== "object") {
      fail(new Error("Codex App Server emitted an invalid RPC message."));
      return;
    }
    if (message.method) {
      if (message.id !== undefined) {
        child.stdin.write(`${JSON.stringify({ id: message.id, error: { code: -32601, message: "This history reader does not execute server requests." } })}\n`);
      }
      return;
    }
    const call = pending.get(message.id);
    if (!call) return;
    pending.delete(message.id);
    clearTimeout(call.timer);
    if (message.error) {
      call.reject(new Error(`${message.error.code ?? "RPC error"}: ${message.error.message ?? "Unknown server error"}`));
    } else if (Object.hasOwn(message, "result")) {
      call.resolve(message.result);
    } else {
      call.reject(new Error("Codex App Server response has neither result nor error."));
    }
  });

  return {
    request(method, params) {
      if (failure) return Promise.reject(failure);
      const id = ++serial;
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          pending.delete(id);
          reject(new Error(`${method} timed out after ${timeoutMs}ms.`));
        }, timeoutMs);
        pending.set(id, { resolve, reject, timer });
        child.stdin.write(`${JSON.stringify({ id, method, params })}\n`);
      });
    },
    notify(method) {
      if (failure) throw failure;
      child.stdin.write(`${JSON.stringify({ method })}\n`);
    },
    async close() {
      input.close();
      child.stdin.end();
      if (closed) return;
      await new Promise((resolve) => {
        const timer = setTimeout(() => child.kill("SIGKILL"), 2000);
        child.once("close", () => { clearTimeout(timer); resolve(); });
        child.kill("SIGTERM");
      });
    },
  };
}

export function parseArgs(argv, env = process.env) {
  const options = { threadId: env.CODEX_THREAD_ID, pageSize: 20, maxPages: 1000, timeoutMs: 30000 };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") return { help: true };
    if (arg === "--thread-id") {
      if (!argv[i + 1] || argv[i + 1].startsWith("--")) throw new Error("--thread-id requires a value.");
      options.threadId = argv[++i];
    } else if (["--page-size", "--max-pages", "--timeout-ms"].includes(arg)) {
      const value = Number(argv[++i]);
      if (!Number.isSafeInteger(value) || value <= 0) throw new Error(`${arg} requires a positive integer.`);
      options[{ "--page-size": "pageSize", "--max-pages": "maxPages", "--timeout-ms": "timeoutMs" }[arg]] = value;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (!options.threadId?.trim()) throw new Error("Pass --thread-id <id> or set CODEX_THREAD_ID.");
  return options;
}

export async function main(argv = process.argv.slice(2)) {
  let client;
  try {
    const options = parseArgs(argv);
    if (options.help) {
      console.log("Usage: node read-thread.mjs [--thread-id <id>] [--page-size 20] [--max-pages 1000] [--timeout-ms 30000]\nDefaults to CODEX_THREAD_ID. Prints JSON containing persisted turns and unmodified items. Reads history only; does not start or resume a thread. Incomplete history exits with status 1.");
      return 0;
    }
    if (Number(process.versions.node.split(".")[0]) < 22) throw new Error("Node.js 22 or newer is required.");
    client = createAppServerClient(options);
    await client.request("initialize", {
      clientInfo: { name: "pstack_codex_history_reader", version: "0.1.0" },
      capabilities: { experimentalApi: true },
    });
    client.notify("initialized");
    const result = await readThreadHistory(client.request, options);
    console.log(JSON.stringify(result, null, 2));
    return result.complete ? 0 : 1;
  } catch (cause) {
    console.error(`read-thread: ${cause instanceof Error ? cause.message : String(cause)}`);
    return 1;
  } finally {
    if (client) await client.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
