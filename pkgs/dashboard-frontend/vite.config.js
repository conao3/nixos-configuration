import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "127.0.0.1",
    port: 5173,
    proxy: {
      "/data": {
        target: "http://127.0.0.1:9500",
        changeOrigin: false,
      },
      "/api": {
        target: "http://127.0.0.1:9500",
        changeOrigin: false,
      },
    },
  },
  build: {
    target: "es2020",
  },
});
