import "./style.css";
import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
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

const KNOWN_URLS: Array<{ port: string; name: string; path?: string }> = [
  { port: "9400", name: "open-webui" },
  { port: "9500", name: "ports-portal" },
];

function DetailRow(props: { label: string; children: React.ReactNode }): React.JSX.Element {
  return (
    <tr>
      <th>{props.label}</th>
      <td>{props.children}</td>
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
            <span className="pathCell" title={cwd}>
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
    <div className="wrap">
      <div className="header">
        <h1>Listening Ports</h1>
        <div className="controls">
          <label className="filterLabel" htmlFor="ipVersionFilter">
            IP Filter
          </label>
          <select
            id="ipVersionFilter"
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
          <div className="meta">{query.isLoading ? "Loading..." : `Updated: ${query.data?.updatedAt ?? "-"}`}</div>
        </div>
      </div>
      <div className="panel knownPanel">
        <h2>KnownURL</h2>
        <div className="knownList">
          {KNOWN_URLS.map((item) => {
            const url = `http://localhost:${item.port}${item.path ?? ""}`;
            const active = listeningPorts.has(item.port);
            return (
              <a key={`${item.port}:${item.name}`} className="knownItem" href={url} target="_blank" rel="noreferrer">
                <span className={active ? "statusUp" : "statusDown"}>{active ? "UP" : "DOWN"}</span>
                <span className="knownName">{item.name}</span>
                <span className="knownUrl">{url}</span>
              </a>
            );
          })}
        </div>
      </div>
      {query.isError ? <div className="error">Failed to load data: {String(query.error)}</div> : null}
      <div className="twoPane">
        <div className="panel listPane">
          <table>
            <thead>
              {table.getHeaderGroups().map((headerGroup) => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map((header) => {
                    const sorted = header.column.getIsSorted();
                    return (
                      <th key={header.id}>
                        {header.isPlaceholder ? null : (
                          <button
                            className="sortButton"
                            type="button"
                            onClick={header.column.getToggleSortingHandler()}
                          >
                            {flexRender(header.column.columnDef.header, header.getContext())}
                            <span className="sortMark">{sorted === "asc" ? " ▲" : sorted === "desc" ? " ▼" : ""}</span>
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
                  className={selectedPort === row.original ? "rowSelected" : ""}
                  onClick={() => setSelectedKey(row.id)}
                >
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="panel detailPane">
          {selectedPort ? (
            <>
              <h2>Port Detail</h2>
              <table className="detailTable">
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
                    <span className="detailValue">{detailQuery.data?.cwd ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Executable">
                    <span className="detailValue">{detailQuery.data?.exe ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Command Line">
                    <span className="detailValue">{detailQuery.data?.cmdline ?? "-"}</span>
                  </DetailRow>
                  <DetailRow label="Started At">{detailQuery.data?.startedAt ?? "-"}</DetailRow>
                  <DetailRow label="Elapsed">{detailQuery.data?.elapsed ?? "-"}</DetailRow>
                  <DetailRow label="Other Listen Ports">{detailQuery.data?.otherListeningPorts?.join(", ") || "-"}</DetailRow>
                </tbody>
              </table>
              {detailQuery.isFetching ? <div className="meta">Loading detail...</div> : null}
              {detailQuery.isError ? <div className="error">Failed to load detail: {String(detailQuery.error)}</div> : null}
            </>
          ) : (
            <div className="meta">No rows</div>
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
