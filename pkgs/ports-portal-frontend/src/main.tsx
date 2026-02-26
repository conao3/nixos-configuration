import "./style.css";
import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

type PortEntry = {
  proto: string;
  address: string;
  port: string;
  process: string;
  pid: string;
};

type PortsResponse = {
  updatedAt?: string;
  ports?: PortEntry[];
};

type AppState = {
  loading: boolean;
  error: string;
  updatedAt: string;
  ports: PortEntry[];
};

function App(): React.JSX.Element {
  const [state, setState] = useState<AppState>({
    loading: true,
    error: "",
    updatedAt: "",
    ports: [],
  });

  useEffect(() => {
    let cancelled = false;

    async function load(): Promise<void> {
      try {
        const response = await fetch("/data/ports.json", { cache: "no-store" });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        const data = (await response.json()) as PortsResponse;
        const ports = (data.ports ?? []).slice().sort((a, b) => {
          const ap = Number.parseInt(a.port, 10);
          const bp = Number.parseInt(b.port, 10);
          if (Number.isNaN(ap) || Number.isNaN(bp)) {
            return 0;
          }
          return ap - bp;
        });
        if (!cancelled) {
          setState({
            loading: false,
            error: "",
            updatedAt: data.updatedAt ?? "-",
            ports,
          });
        }
      } catch (err) {
        if (!cancelled) {
          setState({
            loading: false,
            error: err instanceof Error ? err.message : String(err),
            updatedAt: "-",
            ports: [],
          });
        }
      }
    }

    void load();
    const timer = setInterval(() => {
      void load();
    }, 30000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  return (
    <div className="wrap">
      <div className="header">
        <h1>Listening Ports</h1>
        <div className="meta">{state.loading ? "Loading..." : `Updated: ${state.updatedAt}`}</div>
      </div>
      {state.error ? <div className="error">Failed to load data: {state.error}</div> : null}
      <div className="panel">
        <table>
          <thead>
            <tr>
              <th>Proto</th>
              <th>Local Address</th>
              <th>Port</th>
              <th>Process</th>
              <th>PID</th>
            </tr>
          </thead>
          <tbody>
            {state.ports.map((item, idx) => (
              <tr key={`${item.proto}:${item.address}:${item.port}:${item.pid}:${idx}`}>
                <td>{item.proto}</td>
                <td>{item.address}</td>
                <td>{item.port}</td>
                <td>{item.process}</td>
                <td>{item.pid}</td>
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

createRoot(rootElement).render(<App />);
