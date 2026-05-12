#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const port = process.env.BIRD_CDP_PORT || "9224";
const targetUrl = `http://127.0.0.1:${port}/json/list`;
const birdBin = process.env.BIRD_BIN || "@bird@/bin/bird";

function redact(value, authToken, ct0) {
  return String(value || "")
    .replaceAll(authToken, "[REDACTED]")
    .replaceAll(ct0, "[REDACTED]");
}

async function cdpCall(ws, method, params) {
  cdpCall.id = (cdpCall.id || 0) + 1;
  const id = cdpCall.id;
  ws.send(JSON.stringify({ id, method, ...(params ? { params } : {}) }));

  while (true) {
    const message = await new Promise((resolve, reject) => {
      const onMessage = (event) => {
        cleanup();
        resolve(typeof event.data === "string" ? event.data : Buffer.from(event.data).toString("utf8"));
      };
      const onError = (event) => {
        cleanup();
        reject(event.error || new Error("CDP websocket error"));
      };
      const cleanup = () => {
        ws.removeEventListener("message", onMessage);
        ws.removeEventListener("error", onError);
      };
      ws.addEventListener("message", onMessage, { once: true });
      ws.addEventListener("error", onError, { once: true });
    });
    const response = JSON.parse(message);
    if (response.id === id) {
      if (response.error) {
        throw new Error(JSON.stringify(response.error));
      }
      return response.result || {};
    }
  }
}

async function main() {
  const targets = await fetch(targetUrl).then((response) => response.json());
  const target = targets.find(
    (item) => String(item.url || "").includes("x.com") && item.webSocketDebuggerUrl,
  );
  if (!target) {
    console.error(
      `bird-conao3: no x.com Chrome DevTools target found on port ${port}; open x.com in chrome-devtools profile conao3 first`,
    );
    process.exit(2);
  }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", (event) => reject(event.error || new Error("CDP websocket error")), {
      once: true,
    });
  });

  await cdpCall(ws, "Network.enable");
  const result = await cdpCall(ws, "Network.getCookies", {
    urls: ["https://x.com/", "https://twitter.com/"],
  });
  ws.close();

  const cookies = Object.fromEntries((result.cookies || []).map((cookie) => [cookie.name, cookie.value]));
  const authToken = cookies.auth_token;
  const ct0 = cookies.ct0;
  if (!authToken || !ct0) {
    console.error("bird-conao3: x.com auth_token/ct0 cookies were not found in the active DevTools target");
    process.exit(3);
  }

  const child = spawnSync(
    birdBin,
    ["--auth-token", authToken, "--ct0", ct0, "--plain", ...process.argv.slice(2)],
    { encoding: "utf8", stdio: ["inherit", "pipe", "pipe"] },
  );

  process.stdout.write(redact(child.stdout, authToken, ct0));
  process.stderr.write(redact(child.stderr, authToken, ct0));

  if (child.error) {
    console.error(`bird-conao3: ${child.error.message}`);
    process.exit(1);
  }
  process.exit(child.status ?? 0);
}

main().catch((error) => {
  console.error(`bird-conao3: ${error.message}`);
  process.exit(1);
});
