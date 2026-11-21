import { spawn } from "node:child_process";

export interface TitleOutlineItem {
  role: "user" | "assistant";
  preview: string;
}

const HEAD_ITEMS = 3;
const TAIL_ITEMS = 20;
const PREVIEW_WIDTH = 400;
const TITLE_WIDTH = 120;

export function buildTitlePrompt(
  instructions: string,
  currentTitle: string | null,
  items: readonly TitleOutlineItem[],
): string {
  const selected =
    items.length <= HEAD_ITEMS + TAIL_ITEMS
      ? items
      : [...items.slice(0, HEAD_ITEMS), ...items.slice(-TAIL_ITEMS)];
  const conversation = selected
    .map(
      (item) =>
        `${item.role === "user" ? "User" : "Agent"}: ${item.preview
          .replace(/\s+/gu, " ")
          .trim()
          .slice(0, PREVIEW_WIDTH)}`,
    )
    .join("\n");
  return [
    "Write a short title for the coding-agent conversation below.",
    "Reply with the title only, on a single line, without quotes.",
    instructions.trim(),
    `Previous title: ${currentTitle ?? "(none)"}`,
    "Conversation, oldest first:",
    conversation,
  ].join("\n\n");
}

export function cleanTitle(output: string): string | null {
  const line = output
    .split("\n")
    .map((candidate) => candidate.trim())
    .find((candidate) => candidate !== "");
  if (line === undefined) return null;
  const title = line
    .replace(/^["'`“”]+|["'`“”]+$/gu, "")
    .trim()
    .slice(0, TITLE_WIDTH)
    .trim();
  return title === "" ? null : title;
}

const COMMAND_TIMEOUT_MS = 60_000;

export function runTitleCommand(
  command: string,
  prompt: string,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn("sh", ["-c", command], {
      stdio: ["pipe", "pipe", "pipe"],
      signal: AbortSignal.timeout(COMMAND_TIMEOUT_MS),
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve(stdout);
      else {
        reject(
          new Error(
            `title command exited with ${String(code)}: ${stderr.trim().slice(0, 500)}`,
          ),
        );
      }
    });
    child.stdin.end(prompt);
  });
}
