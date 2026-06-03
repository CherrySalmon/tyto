const path = require('path');
const vue = require('@vitejs/plugin-vue').default;
const { defineConfig } = require('vitest/config');

// Test config for the Vue frontend. Mirrors the webpack '@' alias
// (frontend_app) so component imports resolve the same way they do in the app.
// Element Plus is auto-imported via unplugin in webpack; tests don't run that
// plugin, so specs stub el-* components explicitly.
module.exports = defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'frontend_app'),
    },
  },
  test: {
    environment: 'jsdom',
    include: ['frontend_app/**/*.{test,spec}.js'],
    globals: true,
  },
});
