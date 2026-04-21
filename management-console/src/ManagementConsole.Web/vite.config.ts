import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The Aspire AppHost injects services__api__http__0 (service discovery URL)
// when the Web app is started under Aspire. Fall back to a local API dev URL
// when running `npm run dev` standalone.
const apiUrl =
  process.env.services__api__https__0 ??
  process.env.services__api__http__0 ??
  "http://localhost:5180";

export default defineConfig({
  plugins: [react()],
  server: {
    port: Number(process.env.PORT ?? 5173),
    strictPort: true,
    proxy: {
      "/api": {
        target: apiUrl,
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
