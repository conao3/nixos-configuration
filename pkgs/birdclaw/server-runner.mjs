import http from "node:http";
import { Readable } from "node:stream";
import { readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, extname, join, normalize } from "node:path";
import handler from "./dist/server/server.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const clientDir = join(__dirname, "dist", "client");

const MIME = {
  ".js": "application/javascript",
  ".mjs": "application/javascript",
  ".css": "text/css",
  ".html": "text/html; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".webmanifest": "application/manifest+json",
};

function tryServeStatic(req, res) {
  if (req.method !== "GET" && req.method !== "HEAD") return false;
  const url = new URL(req.url, "http://localhost");
  if (url.pathname === "/" || url.pathname.endsWith("/")) return false;
  const safePath = normalize(url.pathname).replace(/^[\\/]+/, "");
  const filePath = join(clientDir, safePath);
  if (!filePath.startsWith(clientDir)) return false;
  try {
    const stat = statSync(filePath);
    if (!stat.isFile()) return false;
    const ext = extname(filePath).toLowerCase();
    res.writeHead(200, {
      "content-type": MIME[ext] ?? "application/octet-stream",
      "content-length": stat.size,
      "cache-control": "public, max-age=31536000, immutable",
    });
    if (req.method === "HEAD") {
      res.end();
    } else {
      res.end(readFileSync(filePath));
    }
    return true;
  } catch {
    return false;
  }
}

async function handleSsr(req, res) {
  const url = `http://${req.headers.host || "localhost"}${req.url}`;
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) {
    if (Array.isArray(v)) for (const item of v) headers.append(k, item);
    else if (v != null) headers.set(k, String(v));
  }
  const init = { method: req.method, headers };
  if (req.method !== "GET" && req.method !== "HEAD") {
    init.body = Readable.toWeb(req);
    init.duplex = "half";
  }
  const request = new Request(url, init);
  const response = await handler.fetch(request);
  const respHeaders = {};
  response.headers.forEach((value, key) => {
    respHeaders[key] = value;
  });
  res.writeHead(response.status, respHeaders);
  if (response.body) {
    const reader = response.body.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
    } finally {
      reader.releaseLock();
    }
  }
  res.end();
}

const server = http.createServer(async (req, res) => {
  try {
    if (tryServeStatic(req, res)) return;
    await handleSsr(req, res);
  } catch (err) {
    console.error("[birdclaw-server-runner]", err);
    if (!res.headersSent) {
      res.writeHead(500, { "content-type": "text/plain" });
    }
    res.end("Internal Server Error");
  }
});

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? "127.0.0.1";
server.listen(port, host, () => {
  console.log(`birdclaw production server listening on http://${host}:${port}/`);
});
