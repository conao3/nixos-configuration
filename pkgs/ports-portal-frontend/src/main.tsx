import "./style.css";
import React, { useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider, useQuery } from "@tanstack/react-query";
import {
  ColumnDef,
  SortingState,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
} from "@tanstack/react-table";

type PortEntry = {
  proto: string;
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

function App(): React.JSX.Element {
  const [sorting, setSorting] = useState<SortingState>([{ id: "port", desc: false }]);
  const query = useQuery({
    queryKey: ["ports"],
    queryFn: fetchPorts,
    refetchInterval: 30000,
  });

  const columns = useMemo<ColumnDef<PortEntry>[]>(
    () => [
      { accessorKey: "proto", header: "Proto" },
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
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  return (
    <div className="wrap">
      <div className="header">
        <h1>Listening Ports</h1>
        <div className="meta">{query.isLoading ? "Loading..." : `Updated: ${query.data?.updatedAt ?? "-"}`}</div>
      </div>
      {query.isError ? <div className="error">Failed to load data: {String(query.error)}</div> : null}
      <div className="panel">
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
              <tr key={row.id}>
                {row.getVisibleCells().map((cell) => (
                  <td key={cell.id}>{flexRender(cell.column.columnDef.cell, cell.getContext())}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
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
