import assert from "node:assert/strict";
import { test } from "node:test";
import { buildTitlePrompt, cleanTitle, runTitleCommand } from "./title.ts";

test("keeps the first and the latest messages in the prompt", () => {
  const items = Array.from({ length: 40 }, (_, index) => ({
    role: index % 2 === 0 ? ("user" as const) : ("assistant" as const),
    preview: `message ${String(index)}`,
  }));
  const prompt = buildTitlePrompt("Use English.", "Old #tag", items);
  assert.ok(prompt.includes("Use English."));
  assert.ok(prompt.includes("Previous title: Old #tag"));
  assert.ok(prompt.includes("User: message 0\n"));
  assert.ok(prompt.includes("Agent: message 39"));
  assert.ok(!prompt.includes("message 10\n"));
});

test("takes the first non-empty line and strips quotes", () => {
  assert.equal(cleanTitle('\n "Find a home #housing"\nmore'), "Find a home #housing");
  assert.equal(cleanTitle("  \n"), null);
  assert.equal(cleanTitle("x".repeat(300))?.length, 120);
});

test("pipes the prompt to the command and returns its output", async () => {
  assert.equal(await runTitleCommand("tr a-z A-Z", "title #tag"), "TITLE #TAG");
  await assert.rejects(runTitleCommand("echo bad >&2; exit 3", "x"), /exited with 3: bad/u);
});
