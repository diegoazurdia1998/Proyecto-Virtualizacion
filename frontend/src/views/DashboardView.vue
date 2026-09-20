<template>
  <div class="container mt-4">
    <div class="p-5 mb-4 bg-light rounded-3 shadow-sm">
      <div class="container-fluid py-3">
        <h1 class="display-5 fw-bold text-success">Dashboard - El Quetzal</h1>
        <p class="col-md-8 fs-4 text-muted">Panel de control y métricas generales del sistema.</p>
        <p class="fw-bold" :class="backendStatusClass">Estado: {{ backendStatus }}</p>
      </div>
    </div>

    <!-- Tarjetas de Métricas -->
    <div class="row text-center mb-4">
      <div class="col-md-3 mb-3">
        <div class="card shadow-sm border-primary h-100">
          <div class="card-body">
            <h6 class="card-title text-primary">Total Productos</h6>
            <p class="display-6 fw-bold">{{ stats.totalProductos }}</p>
          </div>
        </div>
      </div>

      <div class="col-md-3 mb-3">
        <div class="card shadow-sm border-success h-100">
          <div class="card-body">
            <h6 class="card-title text-success">Valor del Inventario</h6>
            <p class="fs-4 fw-bold">Q {{ stats.valorInventario.toFixed(2) }}</p>
          </div>
        </div>
      </div>

      <div class="col-md-3 mb-3">
        <div class="card shadow-sm border-info h-100">
          <div class="card-body">
            <h6 class="card-title text-info">Pedidos del Día</h6>
            <p class="display-6 fw-bold">{{ stats.pedidosDelDia }}</p>
          </div>
        </div>
      </div>

      <div class="col-md-3 mb-3">
        <div class="card shadow-sm border-danger h-100">
          <div class="card-body">
            <h6 class="card-title text-danger">Stock Bajo (&lt; 10)</h6>
            <p class="display-6 fw-bold">{{ stats.stockBajo }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Alertas visuales de stock bajo -->
    <div v-if="productosStockBajo.length > 0" class="alert alert-warning shadow-sm">
      <h5 class="alert-heading">⚠️ Alerta de Stock Crítico</h5>
      <ul class="mb-0">
        <li v-for="p in productosStockBajo" :key="p.sku">
          <strong>{{ p.nombre }}</strong> (SKU: {{ p.sku }}) - Quedan únicamente <strong>{{ p.stock }}</strong> unidades.
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
import api from '../services/api'

export default {
  name: 'DashboardView',
  data() {
    return {
      stats: {
        totalProductos: 0,
        valorInventario: 0,
        pedidosDelDia: 0,
        stockBajo: 0
      },
      productosStockBajo: [],
      backendStatus: 'Verificando...',
      backendStatusClass: 'text-secondary'
    }
  },
  mounted() {
    this.cargarMetricas()
  },
  methods: {
        async cargarMetricas() {
      try {
        const res = await api.get('/reportes/dashboard')
        const d = res.data

        this.stats.totalProductos = d.total_productos
        this.stats.valorInventario = d.valor_inventario
        this.stats.pedidosDelDia = d.pedidos_hoy
        this.stats.stockBajo = d.stock_bajo.length
        this.productosStockBajo = d.stock_bajo

        this.backendStatus = 'Conectado'
        this.backendStatusClass = 'text-success'
      } catch (err) {
        console.error('Error conectando al backend:', err)
        this.backendStatus = 'Sin conexión'
        this.backendStatusClass = 'text-danger'
      }
    }
  }
}
</script>