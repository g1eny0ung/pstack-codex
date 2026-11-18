import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs, readThreadHistory } from "./read-thread.mjs";

const turn = (id: string) => ({ id, status: "completed", itemsView: "full", items: [{ id: `item-${id}`, type: "agentMessage", text: id }] });

describe("read-thread", () => {
  test("runs the CLI through a symlink", () => {
    const directory = mkdtempSync(join(tmpdir(), "pstack-read-thread-"));
    try {
      const script = join(directory, "read-thread.mjs");
      symlinkSync(fileURLToPath(new URL("./read-thread.mjs", import.meta.url)), script);
      const result = spawnSync("node", [script, "--help"], { encoding: "utf8" });
      expect(result.status).toBe(0);
      expect(result.stdout).toContain("Usage: node read-thread.mjs");
    } finally {
      rmSync(directory, { recursive: true });
    }
  });

  test("reads full pages in order and deduplicates overlapping turns", async () => {
    const calls: unknown[] = [];
    const pages = [
      { data: [turn("a"), turn("b")], nextCursor: "page-2" },
      { data: [turn("b"), turn("c")], nextCursor: null },
    ];
    const result = await readThreadHistory(async (method: string, params: unknown) => {
      calls.push({ method, params });
      return pages.shift();
    }, { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.turns.map((entry: { id: string }) => entry.id)).toEqual(["a", "b", "c"]);
    expect(calls).toEqual([
      { method: "thread/turns/list", params: { threadId: "requested-thread", itemsView: "full", sortDirection: "asc", limit: 20 } },
      { method: "thread/turns/list", params: { threadId: "requested-thread", itemsView: "full", sortDirection: "asc", limit: 20, cursor: "page-2" } },
    ]);
  });

  test("preserves partial history and reports API errors", async () => {
    let calls = 0;
    const result = await readThreadHistory(async () => {
      if (calls++ === 0) return { data: [turn("a")], nextCursor: "more" };
      throw new Error("thread not found");
    }, { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.turns).toHaveLength(1);
    expect(result.error).toContain("thread not found");
  });

  test("marks missing or summary items as incomplete", async () => {
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), itemsView: "summary" }, { ...turn("b"), items: [] }],
      nextCursor: null,
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.warnings.join(" ")).toContain("summary");
    expect(result.warnings.join(" ")).toContain("no persisted items");
  });

  test("marks missing command output as incomplete and preserves the call", async () => {
    const item = { id: "call-1", type: "commandExecution", command: "example", aggregatedOutput: null };
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), items: [item] }],
      nextCursor: null,
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.turns[0].items).toEqual([item]);
    expect(result.warnings.join(" ")).toContain("no persisted tool output");
  });

  test.each([
    { status: "completed", exitCode: 0 },
    { status: "failed", exitCode: 1 },
  ])("preserves a command with an exit code and no output without marking history incomplete", async (resultFields) => {
    const item = { id: "call-1", type: "commandExecution", ...resultFields, aggregatedOutput: null };
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), items: [item] }],
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.turns[0].items).toEqual([item]);
    expect(result.warnings).toEqual([]);
  });

  test.each([
    "... command output truncated for persistence ...\n",
    "head\n... command output truncated for persistence ...\ntail",
  ])("preserves a completed command that prints a truncation marker on its own line", async (aggregatedOutput) => {
    const item = { id: "call-1", type: "commandExecution", status: "completed", exitCode: 0, aggregatedOutput };
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), items: [item] }],
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.turns[0].items).toEqual([item]);
    expect(result.warnings).toEqual(["Turn a, item call-1 may contain truncated tool output; the saved text is preserved."]);
  });

  test("ends pagination when the final page omits the cursor", async () => {
    const result = await readThreadHistory(async () => ({ data: [turn("a")] }), { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.nextCursor).toBeNull();
    expect(result.turns).toEqual([turn("a")]);
  });

  test("rejects a malformed cursor", async () => {
    const result = await readThreadHistory(async () => ({ data: [turn("a")], nextCursor: 1 }), { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.error).toContain("nextCursor");
  });

  test("preserves the current snapshot of an in-progress turn", async () => {
    const active = {
      ...turn("a"), status: "inProgress",
      items: [{ id: "user", type: "userMessage", content: [{ type: "text", text: "Continue", text_elements: [] }] }],
    };
    const result = await readThreadHistory(async () => ({ data: [active] }), { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.warnings.join(" ")).toContain("snapshot");
    expect(result.turns).toEqual([active]);
  });

  test.each([
    { output: "head…17 tokens truncated…tail" },
    { output: [{ type: "inputText", text: "Warning: truncated output (original token count: 17)\nhead" }] },
  ])(
    "warns about possible truncation while preserving standalone tool output",
    async ({ output }) => {
      const item = { id: "call-1", type: "functionCallOutput", name: "run_tests", namespace: null, output };
      const result = await readThreadHistory(async () => ({
        data: [{ ...turn("a"), items: [item] }],
        nextCursor: null,
      }), { threadId: "requested-thread" });
      expect(result.complete).toBe(true);
      expect(result.warnings).toEqual([
        "Turn a, item call-1 may contain truncated tool output; the saved text is preserved.",
      ]);
      expect(result.turns[0].items).toEqual([item]);
    },
  );

  test("preserves MCP text and quoted truncation markers in command output", async () => {
    const items = [
      { id: "mcp", type: "mcpToolCall", result: { content: [{ type: "text", text: "head…17 chars truncated…tail" }] } },
      { id: "log", type: "commandExecution", aggregatedOutput: "Output was not truncated." },
      { id: "quote", type: "commandExecution", aggregatedOutput: 'const marker = "... command output truncated for persistence ...";' },
    ];
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), items }],
      nextCursor: null,
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(true);
    expect(result.warnings).toEqual([
      "Turn a, item mcp may contain truncated tool output; the saved text is preserved.",
      "Turn a, item quote may contain truncated tool output; the saved text is preserved.",
    ]);
    expect(result.turns[0].items).toEqual(items);
  });

  test("stops repeated cursors and records a bounded page limit", async () => {
    const page = async () => ({ data: [turn("a")], nextCursor: "repeat" });
    const repeated = await readThreadHistory(page, { threadId: "requested-thread" });
    expect(repeated.pages).toBe(2);
    expect(repeated.error).toContain("repeated cursor");
    const bounded = await readThreadHistory(page, { threadId: "requested-thread", maxPages: 1 });
    expect(bounded.complete).toBe(false);
    expect(bounded.warnings.join(" ")).toContain("truncated");
  });

  test("uses only the explicit thread or current thread ID", () => {
    expect(parseArgs([], { CODEX_THREAD_ID: "current" }).threadId).toBe("current");
    expect(parseArgs(["--thread-id", "explicit"], { CODEX_THREAD_ID: "current" }).threadId).toBe("explicit");
    expect(() => parseArgs([], {})).toThrow("--thread-id");
    expect(() => parseArgs(["--max-pages", "0"], { CODEX_THREAD_ID: "current" })).toThrow("positive integer");
  });
});
