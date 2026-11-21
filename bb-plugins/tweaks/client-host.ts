import { execFile } from "node:child_process";
import { hostname } from "node:os";
import { promisify } from "node:util";
import { z } from "zod";

const execFileAsync = promisify(execFile);

const tailscaleStatusSchema = z.looseObject({
  Self: z.looseObject({
    HostName: z.string(),
    TailscaleIPs: z.array(z.string()).nullable().optional(),
  }),
  Peer: z
    .record(
      z.string(),
      z.looseObject({
        HostName: z.string(),
        TailscaleIPs: z.array(z.string()).nullable().optional(),
      }),
    )
    .nullable()
    .optional(),
});

export interface TailnetNode {
  hostName: string;
  ips: readonly string[];
}

const LOOPBACK = /^(127\.|::1$|::ffff:127\.)/u;

export function forwardedClientIp(header: string | undefined): string | null {
  const ip = header?.split(",")[0]?.trim() ?? "";
  return ip === "" || LOOPBACK.test(ip) ? null : ip;
}

export function tailnetNodes(statusJson: string): TailnetNode[] {
  const status = tailscaleStatusSchema.parse(JSON.parse(statusJson));
  return [status.Self, ...Object.values(status.Peer ?? {})].map((node) => ({
    hostName: node.HostName,
    ips: node.TailscaleIPs ?? [],
  }));
}

export function hostNameForIp(
  nodes: readonly TailnetNode[],
  ip: string,
): string | null {
  return nodes.find((node) => node.ips.includes(ip))?.hostName ?? null;
}

export async function clientHostName(
  forwardedFor: string | undefined,
  tailscaleCommand: string,
): Promise<string | null> {
  const ip = forwardedClientIp(forwardedFor);
  if (ip === null) return hostname();
  const { stdout } = await execFileAsync(tailscaleCommand, [
    "status",
    "--json",
  ]);
  return hostNameForIp(tailnetNodes(stdout), ip);
}
