import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// En desarrollo, Vite hace de gateway: /api/<servicio>/ va al puerto de cada
// microservicio publicado por docker-compose.override.yml. En producción ese
// ruteo lo hace nginx y este proxy no se usa.
const servicios = {
  '/api/catalogo':   'http://localhost:5001',
  '/api/inventario': 'http://localhost:5000',
  '/api/clientes':   'http://localhost:5002',
  '/api/pedidos':    'http://localhost:5003',
  '/api/reportes':   'http://localhost:5004'
}

const proxy = Object.fromEntries(
  Object.entries(servicios).map(([ruta, destino]) => [
    ruta,
    {
      target: destino,
      changeOrigin: true,
      rewrite: (path) => path.replace(new RegExp(`^${ruta}`), '')
    }
  ])
)

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy
  }
})