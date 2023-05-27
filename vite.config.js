import { fileURLToPath, URL } from 'node:url'
import { resolve } from 'path'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vuetify from 'vite-plugin-vuetify'

const root = fileURLToPath(new URL('./src', import.meta.url))
const publicDir = resolve(root, 'public')
const outDir = fileURLToPath(new URL('./dist', import.meta.url))

// https://vitejs.dev/config/
export default defineConfig({
  root: root,
  publicDir: publicDir,
  plugins: [
    vue(), vuetify()
  ],
  resolve: {
    alias: {
      '@': root
    }
  },
  build: {
    outDir: outDir,
    emptyOutDir: true,
    rollupOptions: {
      input: {
        start: resolve(root, 'index.html')
      }
    }
  },
  server: {
    host: true
  }
})
