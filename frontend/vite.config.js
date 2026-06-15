import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'https://ai-os-export-documentation-production.up.railway.app',
        changeOrigin: true,
      }
    }
  }
})
