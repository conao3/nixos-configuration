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

const KNOWN_URL_GROUPS: Array<{ name: string; items: Array<{ label: string; port: string }> }> = [
  {
    name: "dashboard",
    items: [
      { label: "frontend", port: "9400" },
      { label: "backend", port: "9401" },
    ],
  },
  {
    name: "open-webui",
    items: [{ label: "app", port: "9402" }],
  },
];

function DetailRow(props: { label: string; children: React.ReactNode }): React.JSX.Element {
  return (
    <tr className="align-middle">
      <th className="w-36 border-b border-slate-200 px-3 py-2 text-left font-semibold text-slate-700">{props.label}</th>
      <td className="border-b border-slate-200 px-3 py-2">{props.children}</td>
    </tr>
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
  const query = useQuery({
    queryKey: ["ports"],
    queryFn: fetchPorts,
    refetchInterval: 30000,
  });

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
            <span className="inline-block max-w-[360px] overflow-hidden text-ellipsis whitespace-nowrap align-bottom" title={cwd}>
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

  const detailQuery = useQuery({
    queryKey: ["process-detail", selectedPort?.pid ?? ""],
    queryFn: () => fetchProcessDetail(String(selectedPort?.pid ?? "")),
    enabled: Boolean(selectedPort?.pid && selectedPort.pid !== "-"),
  });
  const listeningPorts = useMemo(
    () => new Set((query.data?.ports ?? []).map((item) => item.port)),
    [query.data?.ports],
  );

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_left,_#f4f9ff,_#edf7f1_55%,_#e7f1ff)] p-4 text-slate-900">
      <div className="mb-3 flex items-end justify-between gap-3">
        <h1 className="m-0 text-3xl font-semibold">Dashboard</h1>
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
        <h2 className="mb-2 text-base font-semibold">KnownURL</h2>
        <div className="grid grid-cols-1 gap-2">
          {KNOWN_URL_GROUPS.map((group) => {
            const upCount = group.items.filter((item) => listeningPorts.has(item.port)).length;
            const groupActive = upCount > 0;
            return (
              <details key={group.name} className="rounded-lg border border-slate-200 bg-slate-50" open>
                <summary className="flex cursor-pointer list-none items-center gap-2 px-3 py-2 [&::-webkit-details-marker]:hidden">
                  <span
                    className={clsx(
                      "rounded-full px-2 py-0.5 text-xs font-bold",
                      {
                        "bg-emerald-100 text-emerald-800": groupActive,
                        "bg-rose-100 text-rose-800": !groupActive,
                      },
                    )}
                  >
                    {groupActive ? "UP" : "DOWN"}
                  </span>
                  <span className="font-semibold">{group.name}</span>
                </summary>
                <div className="grid gap-2 px-2 pb-2">
                  {group.items.map((item) => {
                    const url = `http://localhost:${item.port}`;
                    const active = listeningPorts.has(item.port);
                    return (
                      <a
                        key={`${group.name}:${item.label}:${item.port}`}
                        className="grid grid-cols-[auto_auto_1fr] items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 no-underline"
                        href={url}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <span
                          className={clsx(
                            "rounded-full px-2 py-0.5 text-xs font-bold",
                            {
                              "bg-emerald-100 text-emerald-800": active,
                              "bg-rose-100 text-rose-800": !active,
                            },
                          )}
                        >
                          {active ? "UP" : "DOWN"}
                        </span>
                        <span className="text-sm text-slate-700">{item.label}</span>
                        <span className="truncate text-sm text-slate-600">{url}</span>
                      </a>
                    );
                  })}
                </div>
              </details>
            );
          })}
        </div>
      </div>
      {query.isError ? <div className="px-1 py-2 text-sm text-rose-800">Failed to load data: {String(query.error)}</div> : null}
      <div className="grid h-[1000px] w-full grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)] gap-3 max-[1024px]:grid-cols-1">
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
