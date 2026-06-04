import { fileURLToPath } from 'node:url';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';

// Test config for the Vue frontend. Mirrors the webpack '@' alias
// (frontend_app) so component imports resolve the same way they do in the app.
// Element Plus is auto-imported via unplugin in webpack; tests don't run that
// plugin, so specs stub el-* components explicitly.
//
// ESM (.mjs) on purpose: Vite's CJS Node API is deprecated and removed in
// Vite 6+, so a require()-based config would break on future upgrades.
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./frontend_app', import.meta.url)),
    },
  },
  test: {
    environment: 'jsdom',
    include: ['frontend_app/**/*.{test,spec}.js'],
    globals: true,
  },
});
