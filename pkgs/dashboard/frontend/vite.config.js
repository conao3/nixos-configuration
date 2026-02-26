import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const backendPort = process.env.DASHBOARD_DEV_BACKEND_PORT || "9401";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "127.0.0.1",
    port: 5173,
    proxy: {
      "/data": {
        target: `http://127.0.0.1:${backendPort}`,
        changeOrigin: false,
      },
      "/api": {
        target: `http://127.0.0.1:${backendPort}`,
        changeOrigin: false,
      },
    },
  },
  build: {
    target: "es2020",
  },
});
