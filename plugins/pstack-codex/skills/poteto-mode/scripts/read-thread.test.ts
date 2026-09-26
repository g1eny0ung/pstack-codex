import { describe, expect, test } from "bun:test";
import { parseArgs, readThreadHistory } from "./read-thread.mjs";

const turn = (id: string) => ({ id, status: "completed", itemsView: "full", items: [{ id: `item-${id}`, type: "agentMessage", text: id }] });

describe("read-thread", () => {
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

  test("marks unavailable and truncated tool output without dropping the call", async () => {
    const result = await readThreadHistory(async () => ({
      data: [{ ...turn("a"), items: [
        { id: "call-1", type: "commandExecution", command: "example", aggregatedOutput: null },
        { id: "call-2", type: "commandExecution", command: "example", aggregatedOutput: "Warning: output truncated" },
      ] }],
      nextCursor: null,
    }), { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.turns[0].items).toHaveLength(2);
    expect(result.warnings.join(" ")).toContain("no persisted tool output");
    expect(result.warnings.join(" ")).toContain("truncated tool output");
  });

  test("reports a missing cursor rather than assuming complete history", async () => {
    const result = await readThreadHistory(async () => ({ data: [turn("a")] }), { threadId: "requested-thread" });
    expect(result.complete).toBe(false);
    expect(result.error).toContain("nextCursor");
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
