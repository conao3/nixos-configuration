import "./style.css";
import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import clsx from "clsx";
import { QueryClient, QueryClientProvider, useQuery } from "@tanstack/react-query";
import {
  ColumnFiltersState,
  ColumnDef,
  SortingState,
  VisibilityState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table";

type PortEntry = {
  proto: string;
  ipVersion: "ipv4" | "ipv6";
  address: string;
  port: string;
  process: string;
  pid: string;
  cwd: string;
};

type PortsResponse = {
  updatedAt?: string;
  ports?: PortEntry[];
};

type PortsData = {
  updatedAt: string;
  ports: PortEntry[];
};

type ProcessDetail = {
  pid: string;
  ppid: string;
  user: string;
  cwd: string;
  exe: string;
  cmdline: string;
  startedAt: string;
  elapsed: string;
  otherListeningPorts: string[];
};

type PortCatalogGroup =
  | "helios"
  | "forwarded"
  | "agent-vm"
  | "external"
  | "development"
  | "commented"
  | "docs"
  | "defaults";

type PortCatalogState =
  | "local"
  | "forwarded"
  | "remote"
  | "external"
  | "dev"
  | "commented"
  | "docs"
  | "default";

type PortCatalogEntry = {
  id: string;
  port: string;
  name: string;
  group: PortCatalogGroup;
  state: PortCatalogState;
  purpose: string;
  source: string;
  access: string;
  href?: string;
  note?: string;
  matchCurrentHost?: boolean;
  checkCurrentHostStatus?: boolean;
};

const PORT_GROUPS: Array<{
  id: PortCatalogGroup;
  title: string;
  description: string;
}> = [
  {
    id: "helios",
    title: "helios",
    description: "Current host services configured directly in nixos/configuration.nix.",
  },
  {
    id: "forwarded",
    title: "forwarded to agent-vm",
    description: "Ports bound on helios by QEMU forwarding or the vm-agent SSH tunnel.",
  },
  {
    id: "agent-vm",
    title: "agent-vm local only",
    description: "Services that listen inside agent-vm but are not forwarded back to helios.",
  },
  {
    id: "external",
    title: "external dependencies",
    description: "Upstream endpoints referenced from this repo but not served by this repo itself.",
  },
  {
    id: "development",
    title: "development-only",
    description: "Ports used by dashboard development workflows.",
  },
  {
    id: "commented",
    title: "commented out",
    description: "Ports that appear only in disabled config blocks.",
  },
  {
    id: "docs",
    title: "documentation examples",
    description: "Ports mentioned in local docs, not managed services.",
  },
  {
    id: "defaults",
    title: "module defaults",
    description: "Fallback values defined by modules but overridden in this host config.",
  },
];

const PORT_CATALOG: PortCatalogEntry[] = [
  {
    id: "helios-ssh",
    port: "22",
    name: "OpenSSH (helios)",
    group: "helios",
    state: "local",
    purpose: "Local SSH daemon. The config restricts it to 127.0.0.1 and ::1; port 22 is the default SSH port.",
    source: "nixos/configuration.nix",
    access: "ssh conao@localhost",
    checkCurrentHostStatus: true,
  },
  {
    id: "dashboard-frontend",
    port: "9400",
    name: "Ports Portal frontend",
    group: "helios",
    state: "local",
    purpose: "Nginx frontend for this dashboard.",
    source: "nixos/configuration.nix, nixos/dashboard.nix",
    access: "http://localhost:9400/",
    href: "http://localhost:9400/",
    note: "dashboard.local is the configured vhost name; the host override changes the module default from 9500 to 9400.",
    checkCurrentHostStatus: true,
  },
  {
    id: "dashboard-backend",
    port: "9401",
    name: "Ports Portal backend",
    group: "helios",
    state: "local",
    purpose: "Backend API that serves /data/ports.json and process inspection endpoints.",
    source: "nixos/dashboard.nix, pkgs/dashboard/backend.py",
    access: "http://localhost:9401/data/ports.json",
    href: "http://localhost:9401/data/ports.json",
    checkCurrentHostStatus: true,
  },
  {
    id: "cli-proxy-api-management-center",
    port: "8788",
    name: "CLIProxyAPI Management Center",
    group: "helios",
    state: "local",
    purpose: "Static management UI for CLIProxyAPI, now served directly on helios.",
    source: "hosts/helios/default.nix, pkgs/cli-proxy-api-management-center.nix",
    access: "http://localhost:8788/",
    href: "http://localhost:8788/",
    note: "Moved off agent-vm so it can be opened directly on the host without SSH forwarding.",
    checkCurrentHostStatus: true,
  },
  {
    id: "gitea-http",
    port: "9404",
    name: "Gitea HTTP",
    group: "helios",
    state: "local",
    purpose: "Local Gitea web UI and API endpoint used by the mirror job.",
    source: "nixos/configuration.nix, hosts/helios/default.nix",
    access: "http://localhost:9404/",
    href: "http://localhost:9404/",
    checkCurrentHostStatus: true,
  },
  {
    id: "cgit-http",
    port: "9405",
    name: "cgit",
    group: "helios",
    state: "local",
    purpose: "Local cgit repository browser for /home/conao/ghq.",
    source: "nixos/configuration.nix",
    access: "http://localhost:9405/ or cgit.local",
    href: "http://localhost:9405/",
    checkCurrentHostStatus: true,
  },
  {
    id: "birdclaw-forward",
    port: "9120",
    name: "Birdclaw",
    group: "forwarded",
    state: "forwarded",
    purpose: "Birdclaw web UI running on agent-vm (port 3000), forwarded to helios :9120 by vm-agent-tunnel and aliased to https://birdclaw.localhost by portless.",
    source: "hosts/agent-vm/home.nix, hosts/helios/default.nix",
    access: "https://birdclaw.localhost/",
    href: "https://birdclaw.localhost/",
    note: "Register the portless alias once with `portless alias birdclaw 9120`. Data lives only on agent-vm to avoid SQLite write conflicts.",
    checkCurrentHostStatus: true,
  },
  {
    id: "agent-vm-ssh-forward",
    port: "2222",
    name: "agent-vm SSH forward",
    group: "forwarded",
    state: "forwarded",
    purpose: "QEMU host-side forward into agent-vm guest port 22.",
    source: "hosts/agent-vm/default.nix, Makefile",
    access: "ssh -p 2222 conao@localhost",
    note: "Used by nixos-rebuild switch for the agent VM and by vm-agent-tunnel.",
    checkCurrentHostStatus: true,
  },
  {
    id: "hermes-dashboard-forward",
    port: "9119",
    name: "Hermes Dashboard",
    group: "forwarded",
    state: "forwarded",
    purpose: "Hermes dashboard running on agent-vm and exposed on helios through autossh.",
    source: "hosts/agent-vm/home.nix, hosts/helios/default.nix",
    access: "http://localhost:9119/",
    href: "http://localhost:9119/",
    checkCurrentHostStatus: true,
  },
  {
    id: "hermes-webui-forward",
    port: "8787",
    name: "Hermes Web UI",
    group: "forwarded",
    state: "forwarded",
    purpose: "Hermes Web UI on agent-vm, forwarded back to helios by vm-agent-tunnel.",
    source: "hosts/agent-vm/home.nix, hosts/helios/default.nix",
    access: "http://localhost:8787/",
    href: "http://localhost:8787/",
    checkCurrentHostStatus: true,
  },
  {
    id: "agent-vm-port-18789",
    port: "18789",
    name: "agent-vm tunnel slot 18789",
    group: "forwarded",
    state: "forwarded",
    purpose: "SSH -L tunnel slot from helios to the same port on agent-vm.",
    source: "hosts/helios/default.nix",
    access: "http://localhost:18789/ if the agent-vm side binds it",
    href: "http://localhost:18789/",
    note: "The old dashboard labeled this as openclaw-gw, but nixos-configuration does not define the producer explicitly.",
    checkCurrentHostStatus: true,
  },
  {
    id: "agent-vm-port-18792",
    port: "18792",
    name: "agent-vm tunnel slot 18792",
    group: "forwarded",
    state: "forwarded",
    purpose: "Second SSH -L tunnel slot from helios to the same port on agent-vm.",
    source: "hosts/helios/default.nix",
    access: "http://localhost:18792/ if the agent-vm side binds it",
    href: "http://localhost:18792/",
    note: "The old dashboard labeled this as openclaw-health, but nixos-configuration does not define the producer explicitly.",
    checkCurrentHostStatus: true,
  },
  {
    id: "agent-vm-port-18701",
    port: "18701",
    name: "agent-vm tunnel slot 18701",
    group: "forwarded",
    state: "forwarded",
    purpose: "Third SSH -L tunnel slot from helios to the same port on agent-vm.",
    source: "hosts/helios/default.nix",
    access: "http://localhost:18701/ if the agent-vm side binds it",
    href: "http://localhost:18701/",
    note: "The old dashboard called this openclaw-qmd. Runtime on 2026-05-05 showed qmd-mcp on 8181 instead, so 18701 is kept as an unlabeled tunnel slot.",
    checkCurrentHostStatus: true,
  },
  {
    id: "agent-vm-ssh",
    port: "22",
    name: "OpenSSH (agent-vm guest)",
    group: "agent-vm",
    state: "remote",
    purpose: "SSH daemon inside the VM guest. The host reaches it through port 2222.",
    source: "hosts/agent-vm/default.nix, nixos/configuration.nix",
    access: "guest port 22 inside agent-vm",
    note: "Not visible on helios directly; the repo forwards it to localhost:2222.",
    matchCurrentHost: false,
  },
  {
    id: "qmd-mcp-http",
    port: "8181",
    name: "QMD MCP HTTP",
    group: "agent-vm",
    state: "remote",
    purpose: "HTTP MCP endpoint started by qmd mcp --http on agent-vm.",
    source: "hosts/agent-vm/home.nix + runtime check",
    access: "agent-vm: http://localhost:8181/mcp",
    note: "The systemd status on 2026-05-05 confirmed this default runtime port; the repo does not set it explicitly.",
    matchCurrentHost: false,
  },
  {
    id: "chrome-devtools",
    port: "9222",
    name: "Chrome DevTools remote debugging",
    group: "agent-vm",
    state: "remote",
    purpose: "Remote debugging endpoint for the Chrome instance used by chrome-devtools-mcp.",
    source: "hosts/agent-vm/home.nix",
    access: "agent-vm: http://localhost:9222/json/version",
    note: "Bound to 127.0.0.1 in the VM and not forwarded to helios.",
    matchCurrentHost: false,
  },
  {
    id: "penpot-mcp",
    port: "4401",
    name: "Penpot MCP",
    group: "external",
    state: "external",
    purpose: "HTTP MCP endpoint expected by the Claude/Codex penpot client configuration.",
    source: "home-manager/features/claude/default.nix",
    access: "http://localhost:4401/mcp",
    href: "http://localhost:4401/mcp",
    note: "Referenced by this repo, but the server itself is not defined here.",
  },
  {
    id: "ollama-tailnet",
    port: "11434",
    name: "Ollama on remote Tailscale host",
    group: "external",
    state: "external",
    purpose: "Remote Ollama API used for OpenClaw heartbeat models.",
    source: "hosts/agent-vm/home.nix",
    access: "http://yamashita-naoya-con0178-3.tail6dd115.ts.net:11434",
    note: "This is an upstream remote endpoint, not a local listener on helios or agent-vm.",
    matchCurrentHost: false,
  },
  {
    id: "dashboard-vite-dev",
    port: "5173",
    name: "Dashboard Vite dev server",
    group: "development",
    state: "dev",
    purpose: "Frontend hot-reload server used by pkgs/dashboard/frontend during development.",
    source: "pkgs/dashboard/frontend/vite.config.js",
    access: "http://127.0.0.1:5173/",
    href: "http://127.0.0.1:5173/",
    note: "Started by make dev or pnpm dev, not by the system service.",
  },
  {
    id: "dashboard-dev-backend",
    port: "9411",
    name: "Dashboard dev backend",
    group: "development",
    state: "dev",
    purpose: "Backend port used by pkgs/dashboard Makefile and flake dev shells.",
    source: "pkgs/dashboard/Makefile, pkgs/dashboard/flake.nix",
    access: "http://127.0.0.1:9411/data/ports.json",
    href: "http://127.0.0.1:9411/data/ports.json",
  },
  {
    id: "open-webui-commented",
    port: "9402",
    name: "Open WebUI",
    group: "commented",
    state: "commented",
    purpose: "Disabled Open WebUI service block in nixos/configuration.nix.",
    source: "nixos/configuration.nix",
    access: "would be http://127.0.0.1:9402/ if enabled",
  },
  {
    id: "ollama-commented",
    port: "9403",
    name: "Local Ollama API",
    group: "commented",
    state: "commented",
    purpose: "Commented Open WebUI upstream target for a local Ollama API.",
    source: "nixos/configuration.nix",
    access: "would be http://127.0.0.1:9403/ if enabled",
  },
  {
    id: "mo-default",
    port: "6275",
    name: "mo default session server",
    group: "docs",
    state: "docs",
    purpose: "Documentation example for the default mo markdown session server.",
    source: "docs/tools/mo.md",
    access: "http://localhost:6275/",
    href: "http://localhost:6275/",
    note: "Example only; this repo does not start the service.",
  },
  {
    id: "mo-alt",
    port: "6276",
    name: "mo alternate session server",
    group: "docs",
    state: "docs",
    purpose: "Documentation example for running a second mo session on a different port.",
    source: "docs/tools/mo.md",
    access: "http://localhost:6276/",
    href: "http://localhost:6276/",
    note: "Example only; this repo does not start the service.",
  },
  {
    id: "dashboard-default-frontend",
    port: "9500",
    name: "Dashboard module default frontend port",
    group: "defaults",
    state: "default",
    purpose: "Default services.dashboard.port value before this host overrides it to 9400.",
    source: "nixos/dashboard.nix",
    access: "would be http://127.0.0.1:9500/ without the override",
  },
];

const STATE_LABELS: Record<PortCatalogState, string> = {
  local: "LOCAL",
  forwarded: "FORWARDED",
  remote: "AGENT-VM",
  external: "EXTERNAL",
  dev: "DEV",
  commented: "COMMENTED",
  docs: "DOCS",
  default: "DEFAULT",
};

const STATE_CLASSES: Record<PortCatalogState, string> = {
  local: "bg-emerald-100 text-emerald-800",
  forwarded: "bg-sky-100 text-sky-800",
  remote: "bg-amber-100 text-amber-800",
  external: "bg-violet-100 text-violet-800",
  dev: "bg-cyan-100 text-cyan-800",
  commented: "bg-rose-100 text-rose-800",
  docs: "bg-stone-100 text-stone-800",
  default: "bg-slate-200 text-slate-800",
};

function buildCatalogByPort(entries: PortCatalogEntry[]): Record<string, PortCatalogEntry[]> {
  const byPort: Record<string, PortCatalogEntry[]> = {};
  for (const entry of entries) {
    byPort[entry.port] = byPort[entry.port] ?? [];
    byPort[entry.port].push(entry);
  }
  return byPort;
}

function sortCatalogEntries(entries: PortCatalogEntry[]): PortCatalogEntry[] {
  return [...entries].sort((a, b) => {
    const portDelta = Number(a.port) - Number(b.port);
    if (portDelta !== 0) {
      return portDelta;
    }
    return a.name.localeCompare(b.name);
  });
}

const SORTED_PORT_CATALOG = sortCatalogEntries(PORT_CATALOG);
const CATALOG_BY_GROUP = PORT_GROUPS.map((group) => ({
  ...group,
  items: SORTED_PORT_CATALOG.filter((entry) => entry.group === group.id),
}));
const CURRENT_HOST_CATALOG = SORTED_PORT_CATALOG.filter((entry) => entry.matchCurrentHost !== false);
const PORT_CATALOG_BY_PORT = buildCatalogByPort(SORTED_PORT_CATALOG);
const CURRENT_HOST_CATALOG_BY_PORT = buildCatalogByPort(CURRENT_HOST_CATALOG);

function DetailRow(props: { label: string; children: React.ReactNode }): React.JSX.Element {
  return (
    <tr className="align-middle">
      <th className="w-40 border-b border-slate-200 px-3 py-2 text-left font-semibold text-slate-700">{props.label}</th>
      <td className="border-b border-slate-200 px-3 py-2">{props.children}</td>
    </tr>
  );
}

function CatalogStateBadge(props: { state: PortCatalogState }): React.JSX.Element {
  return (
    <span className={clsx("rounded-full px-2 py-0.5 text-xs font-bold", STATE_CLASSES[props.state])}>
      {STATE_LABELS[props.state]}
    </span>
  );
}

function LocalStatusBadge(props: {
  active: boolean;
  visible: boolean;
}): React.JSX.Element | null {
  if (!props.visible) {
    return null;
  }

  return (
    <span
      className={clsx("rounded-full px-2 py-0.5 text-xs font-bold", {
        "bg-emerald-100 text-emerald-800": props.active,
        "bg-rose-100 text-rose-800": !props.active,
      })}
    >
      {props.active ? "LOCAL UP" : "LOCAL DOWN"}
    </span>
  );
}

function AccessValue(props: {
  access: string;
  href?: string;
}): React.JSX.Element {
  if (!props.href) {
    return <span className="break-all">{props.access}</span>;
  }

  return (
    <a className="break-all text-sky-800 underline decoration-sky-300 underline-offset-2" href={props.href} target="_blank" rel="noreferrer">
      {props.access}
    </a>
  );
}

async function fetchPorts(): Promise<PortsData> {
  const response = await fetch("/data/ports.json", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const data = (await response.json()) as PortsResponse;
  return {
    updatedAt: data.updatedAt ?? "-",
    ports: data.ports ?? [],
  };
}

async function fetchProcessDetail(pid: string): Promise<ProcessDetail> {
  const response = await fetch(`/api/process/${pid}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return (await response.json()) as ProcessDetail;
}

function App(): React.JSX.Element {
  const [sorting, setSorting] = useState<SortingState>([{ id: "port", desc: false }]);
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([
    { id: "ipVersion", value: "ipv4" },
  ]);
  const [columnVisibility] = useState<VisibilityState>({
    ipVersion: false,
  });
  const [selectedKey, setSelectedKey] = useState<string>("");
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(PORT_GROUPS.map((group) => [group.id, true])),
  );
  const query = useQuery({
    queryKey: ["ports"],
    queryFn: fetchPorts,
    refetchInterval: 30000,
  });

  const listeningPorts = useMemo(
    () => new Set((query.data?.ports ?? []).map((item) => item.port)),
    [query.data?.ports],
  );

  const columns = useMemo<ColumnDef<PortEntry>[]>(
    () => [
      { accessorKey: "proto", header: "Proto" },
      { accessorKey: "ipVersion", header: "IP Version" },
      { accessorKey: "address", header: "Local Address" },
      {
        accessorKey: "port",
        header: "Port",
        cell: (info) => {
          const port = String(info.getValue());
          return (
            <a href={`http://localhost:${port}`} target="_blank" rel="noreferrer">
              {port}
            </a>
          );
        },
        sortingFn: (a, b, id) => Number(a.getValue(id)) - Number(b.getValue(id)),
      },
      {
        id: "knownAs",
        header: "Known As",
        cell: (info) => {
          const port = String(info.row.original.port);
          const matches = CURRENT_HOST_CATALOG_BY_PORT[port] ?? [];
          if (matches.length === 0) {
            return <span className="text-slate-400">-</span>;
          }

          return (
            <div className="grid gap-1">
              {matches.map((entry) => (
                <div key={entry.id} className="leading-tight">
                  <div className="font-medium text-slate-800">{entry.name}</div>
                  <div className="text-xs text-slate-500">{STATE_LABELS[entry.state]}</div>
                </div>
              ))}
            </div>
          );
        },
      },
      { accessorKey: "process", header: "Process" },
      {
        accessorKey: "pid",
        header: "PID",
        sortingFn: (a, b, id) => Number(a.getValue(id)) - Number(b.getValue(id)),
      },
      {
        accessorKey: "cwd",
        header: "Working Dir",
        cell: (info) => {
          const cwd = String(info.getValue());
          return (
            <span className="inline-block max-w-[320px] overflow-hidden text-ellipsis whitespace-nowrap align-bottom" title={cwd}>
              {cwd}
            </span>
          );
        },
      },
    ],
    [],
  );

  const table = useReactTable({
    data: query.data?.ports ?? [],
    columns,
    state: { sorting, columnFilters, columnVisibility },
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  const selectedPort = useMemo(() => {
    if (!selectedKey) {
      return table.getRowModel().rows[0]?.original;
    }
    return table.getRowModel().rows.find((row) => row.id === selectedKey)?.original ?? table.getRowModel().rows[0]?.original;
  }, [selectedKey, table]);

  const selectedCatalogEntries = useMemo(() => {
    const port = selectedPort?.port;
    if (!port) {
      return [];
    }

    const currentHostMatches = CURRENT_HOST_CATALOG_BY_PORT[port] ?? [];
    if (currentHostMatches.length > 0) {
      return currentHostMatches;
    }

    return PORT_CATALOG_BY_PORT[port] ?? [];
  }, [selectedPort]);

  const detailQuery = useQuery({
    queryKey: ["process-detail", selectedPort?.pid ?? ""],
    queryFn: () => fetchProcessDetail(String(selectedPort?.pid ?? "")),
    enabled: Boolean(selectedPort?.pid && selectedPort.pid !== "-"),
  });

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_left,_#f4f9ff,_#edf7f1_55%,_#e7f1ff)] p-4 text-slate-900">
      <div className="mb-3 flex items-end justify-between gap-3">
        <div>
          <h1 className="m-0 text-3xl font-semibold">Ports Portal</h1>
          <div className="pt-1 text-sm text-slate-700">
            Live listeners from <code>ss -lntupH</code> plus a repo-derived catalog of what each port is for.
          </div>
        </div>
        <div className="flex items-center gap-2">
          <label className="text-sm text-slate-700" htmlFor="ipVersionFilter">
            IP Filter
          </label>
          <select
            id="ipVersionFilter"
            className="rounded-md border border-slate-300 bg-white px-2 py-1 text-sm"
            value={String(table.getColumn("ipVersion")?.getFilterValue() ?? "all")}
            onChange={(event) => {
              const value = event.target.value;
              table.getColumn("ipVersion")?.setFilterValue(value === "all" ? undefined : value);
            }}
          >
            <option value="ipv4">IPv4</option>
            <option value="ipv6">IPv6</option>
            <option value="all">All</option>
          </select>
          <div className="text-sm text-slate-700">{query.isLoading ? "Loading..." : `Updated: ${query.data?.updatedAt ?? "-"}`}</div>
        </div>
      </div>

      <div className="mb-3 rounded-xl border border-slate-200 bg-white/85 p-3 shadow-md shadow-slate-400/10">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="mb-1 text-base font-semibold">Port Catalog</h2>
            <div className="text-sm text-slate-700">
              This list comes from the whole <code>nixos-configuration</code> tree, including host configs, dev shells, and docs.
            </div>
          </div>
        </div>
        <div className="grid grid-cols-1 gap-3">
          {CATALOG_BY_GROUP.map((group) => {
            const isOpen = openGroups[group.id] ?? true;
            return (
              <div key={group.id} className="rounded-lg border border-slate-200 bg-slate-50">
                <button
                  className="flex w-full cursor-pointer items-start justify-between gap-3 px-3 py-2 text-left"
                  type="button"
                  onClick={() =>
                    setOpenGroups((prev) => ({
                      ...prev,
                      [group.id]: !(prev[group.id] ?? true),
                    }))
                  }
                >
                  <div>
                    <div className="font-semibold">{group.title}</div>
                    <div className="text-sm text-slate-600">{group.description}</div>
                  </div>
                  <div className="text-xs font-semibold text-slate-500">{group.items.length} ports</div>
                </button>
                {isOpen ? (
                  <div className="grid gap-2 px-2 pb-2">
                    {group.items.map((entry) => {
                      const isLocalUp = listeningPorts.has(entry.port);
                      return (
                        <div key={entry.id} className="rounded-lg border border-slate-200 bg-white px-3 py-2">
                          <div className="mb-1 flex flex-wrap items-center gap-2">
                            <CatalogStateBadge state={entry.state} />
                            <LocalStatusBadge
                              active={isLocalUp}
                              visible={Boolean(entry.checkCurrentHostStatus)}
                            />
                            <span className="font-mono text-sm font-semibold text-slate-800">{entry.port}</span>
                            <span className="font-semibold text-slate-900">{entry.name}</span>
                          </div>
                          <div className="text-sm text-slate-800">{entry.purpose}</div>
                          <div className="mt-2 grid gap-1 text-xs text-slate-600">
                            <div>
                              <span className="font-semibold text-slate-700">Access:</span>{" "}
                              <AccessValue access={entry.access} href={entry.href} />
                            </div>
                            <div>
                              <span className="font-semibold text-slate-700">Source:</span>{" "}
                              <span className="break-all font-mono">{entry.source}</span>
                            </div>
                            {entry.note ? (
                              <div>
                                <span className="font-semibold text-slate-700">Note:</span> {entry.note}
                              </div>
                            ) : null}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </div>

      {query.isError ? <div className="px-1 py-2 text-sm text-rose-800">Failed to load data: {String(query.error)}</div> : null}

      <div className="grid h-[1000px] w-full grid-cols-[minmax(0,1.45fr)_minmax(360px,1fr)] gap-3 max-[1024px]:grid-cols-1">
        <div className="overflow-auto rounded-xl border border-slate-200 bg-white/85 p-0 shadow-md shadow-slate-400/10">
          <table className="w-full border-collapse">
            <thead>
              {table.getHeaderGroups().map((headerGroup) => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map((header) => {
                    const sorted = header.column.getIsSorted();
                    return (
                      <th key={header.id} className="sticky top-0 z-[2] border-b border-slate-200 bg-emerald-50 px-3 py-2 text-left font-semibold">
                        {header.isPlaceholder ? null : (
                          <button
                            className="w-full cursor-pointer text-left"
                            type="button"
                            onClick={header.column.getToggleSortingHandler()}
                          >
                            {flexRender(header.column.columnDef.header, header.getContext())}
                            <span className="text-slate-500">{sorted === "asc" ? " ▲" : sorted === "desc" ? " ▼" : ""}</span>
                          </button>
                        )}
                      </th>
                    );
                  })}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.map((row) => (
                <tr
                  key={row.id}
                  className={clsx("cursor-pointer", {
                    "bg-emerald-100": selectedPort === row.original,
                  })}
                  onClick={() => setSelectedKey(row.id)}
                >
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="border-b border-slate-200 px-3 py-2 align-middle text-sm">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="overflow-auto rounded-xl border border-slate-200 bg-white/85 p-3 shadow-md shadow-slate-400/10">
          {selectedPort ? (
            <>
              <h2 className="mb-2 text-lg font-semibold">Port Detail</h2>
              <table className="w-full table-fixed border-collapse">
                <tbody>
                  <DetailRow label="Proto">{selectedPort.proto}</DetailRow>
                  <DetailRow label="Address">{selectedPort.address}</DetailRow>
                  <DetailRow label="IP Version">{selectedPort.ipVersion}</DetailRow>
                  <DetailRow label="Port">
                    <a href={`http://localhost:${selectedPort.port}`} target="_blank" rel="noreferrer">
                      {selectedPort.port}
                    </a>
                  </DetailRow>
                  <DetailRow label="Catalog">
                    {selectedCatalogEntries.length > 0 ? (
                      <div className="grid gap-2">
                        {selectedCatalogEntries.map((entry) => (
                          <div key={entry.id} className="rounded-lg border border-slate-200 bg-slate-50 p-2">
                            <div className="mb-1 flex flex-wrap items-center gap-2">
                              <CatalogStateBadge state={entry.state} />
                              <span className="font-semibold">{entry.name}</span>
                            </div>
                            <div className="text-sm text-slate-800">{entry.purpose}</div>
                            <div className="pt-2 text-xs text-slate-600">
                              <div>
                                <span className="font-semibold text-slate-700">Access:</span>{" "}
                                <AccessValue access={entry.access} href={entry.href} />
                              </div>
                              <div>
                                <span className="font-semibold text-slate-700">Source:</span>{" "}
                                <span className="break-all font-mono">{entry.source}</span>
                              </div>
                              {entry.note ? (
                                <div>
                                  <span className="font-semibold text-slate-700">Note:</span> {entry.note}
                                </div>
                              ) : null}
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : (
                      "-"
                    )}
                  </DetailRow>
                  <DetailRow label="Process">{selectedPort.process}</DetailRow>
                  <DetailRow label="PID">{selectedPort.pid}</DetailRow>
                  <DetailRow label="User">{detailQuery.data?.user ?? "-"}</DetailRow>
                  <DetailRow label="PPID">{detailQuery.data?.ppid ?? "-"}</DetailRow>
                  <DetailRow label="Working Dir">
                    <span className="break-all font-mono text-[0.9rem]">{detailQuery.data?.cwd ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Executable">
                    <span className="break-all font-mono text-[0.9rem]">{detailQuery.data?.exe ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Command Line">
                    <span className="break-all font-mono text-[0.9rem]">{detailQuery.data?.cmdline ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Started At">{detailQuery.data?.startedAt ?? "-"}</DetailRow>
                  <DetailRow label="Elapsed">{detailQuery.data?.elapsed ?? "-"}</DetailRow>
                  <DetailRow label="Other Listen Ports">{detailQuery.data?.otherListeningPorts?.join(", ") || "-"}</DetailRow>
                </tbody>
              </table>
              {detailQuery.isFetching ? <div className="pt-2 text-sm text-slate-700">Loading detail...</div> : null}
              {detailQuery.isError ? <div className="pt-2 text-sm text-rose-800">Failed to load detail: {String(detailQuery.error)}</div> : null}
            </>
          ) : (
            <div className="text-sm text-slate-700">No rows</div>
          )}
        </div>
      </div>
    </div>
  );
}

const rootElement = document.getElementById("app");
if (!rootElement) {
  throw new Error("app root element was not found");
}

const queryClient = new QueryClient();
createRoot(rootElement).render(
  <QueryClientProvider client={queryClient}>
    <App />
  </QueryClientProvider>,
);
