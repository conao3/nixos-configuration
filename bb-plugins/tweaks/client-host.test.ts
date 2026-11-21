import assert from "node:assert/strict";
import { test } from "node:test";
import { forwardedClientIp, hostNameForIp, tailnetNodes } from "./client-host.ts";

const status = JSON.stringify({
  Self: { HostName: "server", TailscaleIPs: ["100.0.0.1", "fd7a::1"] },
  Peer: {
    a: { HostName: "laptop", TailscaleIPs: ["100.0.0.2", "fd7a::2"] },
    b: { HostName: "offline", TailscaleIPs: null },
  },
});

test("forwardedClientIp takes the first forwarded address", () => {
  assert.equal(forwardedClientIp("100.0.0.2, 10.0.0.1"), "100.0.0.2");
  assert.equal(forwardedClientIp("fd7a::2"), "fd7a::2");
});

test("forwardedClientIp treats a missing or loopback address as the server itself", () => {
  assert.equal(forwardedClientIp(undefined), null);
  assert.equal(forwardedClientIp(""), null);
  assert.equal(forwardedClientIp("127.0.0.1"), null);
  assert.equal(forwardedClientIp("::1"), null);
  assert.equal(forwardedClientIp("::ffff:127.0.0.1"), null);
});

test("hostNameForIp resolves the server and peers by any tailnet address", () => {
  const nodes = tailnetNodes(status);
  assert.equal(hostNameForIp(nodes, "100.0.0.1"), "server");
  assert.equal(hostNameForIp(nodes, "fd7a::2"), "laptop");
  assert.equal(hostNameForIp(nodes, "100.0.0.9"), null);
});
