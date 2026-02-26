import "./style.css";
import React from "react";
import { createRoot } from "react-dom/client";

const h = React.createElement;

function App() {
  const [state, setState] = React.useState({
    loading: true,
    error: "",
    updatedAt: "",
    ports: [],
  });

  React.useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const response = await fetch("/data/ports.json", { cache: "no-store" });
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        const data = await response.json();
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

    load();
    const timer = setInterval(load, 30000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  const rows = state.ports.map((item, idx) =>
    h(
      "tr",
      { key: `${item.proto}:${item.address}:${item.port}:${item.pid}:${idx}` },
      h("td", null, item.proto),
      h("td", null, item.address),
      h("td", null, item.port),
      h("td", null, item.process),
      h("td", null, item.pid),
    ),
  );

  return h(
    "div",
    { className: "wrap" },
    h(
      "div",
      { className: "header" },
      h("h1", null, "Listening Ports"),
      h(
        "div",
        { className: "meta" },
        state.loading ? "Loading..." : `Updated: ${state.updatedAt}`,
      ),
    ),
    state.error ? h("div", { className: "error" }, `Failed to load data: ${state.error}`) : null,
    h(
      "div",
      { className: "panel" },
      h(
        "table",
        null,
        h(
          "thead",
          null,
          h(
            "tr",
            null,
            h("th", null, "Proto"),
            h("th", null, "Local Address"),
            h("th", null, "Port"),
            h("th", null, "Process"),
            h("th", null, "PID"),
          ),
        ),
        h("tbody", null, rows),
      ),
    ),
  );
}

const root = createRoot(document.getElementById("app"));
root.render(h(App));
