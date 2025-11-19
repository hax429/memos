import react from "@vitejs/plugin-react";
import { resolve } from "path";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

let devProxyServer = "http://localhost:8081";
if (process.env.DEV_PROXY_SERVER && process.env.DEV_PROXY_SERVER.length > 0) {
  console.log("Use devProxyServer from environment: ", process.env.DEV_PROXY_SERVER);
  devProxyServer = process.env.DEV_PROXY_SERVER;
}

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: "0.0.0.0",
    port: 3001,
    proxy: {
      "^/api": {
        target: devProxyServer,
        xfwd: true,
      },
      "^/memos.api.v1": {
        target: devProxyServer,
        xfwd: true,
      },
      "^/file": {
        target: devProxyServer,
        xfwd: true,
      },
    },
  },
  resolve: {
    alias: {
      "@/": `${resolve(__dirname, "src")}/`,
    },
  },
  build: {
    // Enable performance optimizations
    target: "esnext",
    minify: "terser",
    terserOptions: {
      compress: {
        drop_console: true, // Remove console.logs in production
        drop_debugger: true,
        pure_funcs: ["console.log", "console.debug"], // Remove specific console methods
      },
    },
    // Optimize chunk size
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          // Split node_modules into separate chunks
          if (id.includes("node_modules")) {
            // Core React and routing
            if (id.includes("react") || id.includes("react-dom") || id.includes("react-router")) {
              return "react-vendor";
            }
            // State management
            if (id.includes("mobx")) {
              return "mobx-vendor";
            }
            // UI components
            if (id.includes("@radix-ui") || id.includes("lucide-react")) {
              return "ui-vendor";
            }
            // Markdown and syntax highlighting
            if (id.includes("react-markdown") || id.includes("remark") || id.includes("rehype") || id.includes("highlight.js")) {
              return "markdown-vendor";
            }
            // Math rendering
            if (id.includes("katex")) {
              return "katex-vendor";
            }
            // Diagrams
            if (id.includes("mermaid")) {
              return "mermaid-vendor";
            }
            // Maps
            if (id.includes("leaflet")) {
              return "leaflet-vendor";
            }
            // Date and utilities
            if (id.includes("dayjs") || id.includes("lodash")) {
              return "utils-vendor";
            }
            // gRPC and API
            if (id.includes("grpc") || id.includes("protobuf")) {
              return "grpc-vendor";
            }
            // Other node_modules
            return "vendor";
          }
        },
        // Optimize asset file names
        assetFileNames: (assetInfo) => {
          const info = assetInfo.name?.split(".") || [];
          const ext = info[info.length - 1];
          if (/png|jpe?g|svg|gif|tiff|bmp|ico/i.test(ext)) {
            return "assets/images/[name]-[hash][extname]";
          } else if (/woff2?|ttf|eot/i.test(ext)) {
            return "assets/fonts/[name]-[hash][extname]";
          }
          return "assets/[name]-[hash][extname]";
        },
        chunkFileNames: "js/[name]-[hash].js",
        entryFileNames: "js/[name]-[hash].js",
      },
    },
    // Improve sourcemap generation
    sourcemap: false, // Disable sourcemaps in production for smaller bundle
  },
});
