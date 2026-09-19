<template>
  <div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
      <h2>Gestión de Inventario</h2>
      <button class="btn btn-success" @click="abrirModalCrear">Nuevo Producto</button>
    </div>

    <!-- Tabla de Productos -->
    <div class="card shadow-sm">
      <div class="card-body">
        <table class="table table-striped align-middle">
          <thead>
            <tr>
              <th>SKU</th>
              <th>Nombre</th>
              <th>Categoría</th>
              <th>Precio (Q)</th>
              <th>Stock</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="prod in productos" :key="prod.id">
              <td><strong>{{ prod.sku }}</strong></td>
              <td>{{ prod.nombre }}</td>
              <td><span class="badge bg-secondary">{{ prod.categoria }}</span></td>
              <td>Q {{ Number(prod.precio).toFixed(2) }}</td>
              <td>
                <span :class="prod.stock < 5 ? 'text-danger fw-bold' : ''">
                  {{ prod.stock }} {{ prod.stock < 5 ? '⚠️' : '' }}
                </span>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-2" @click="abrirModalEditar(prod)">Editar</button>
                <button class="btn btn-sm btn-outline-danger" @click="eliminarProducto(prod.id)">Eliminar</button>
              </td>
            </tr>
            <tr v-if="productos.length === 0">
              <td colspan="6" class="text-center text-muted">No hay productos registrados.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal simple para Crear/Editar -->
    <div v-if="mostrarModal" class="modal show d-block" tabindex="-1" style="background: rgba(0,0,0,0.5);">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editando ? 'Editar Producto' : 'Nuevo Producto' }}</h5>
            <button type="button" class="btn-close" @click="cerrarModal"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="guardarProducto">
              <div class="mb-3">
                <label class="form-label">SKU</label>
                <input type="text" class="form-control" v-model="form.sku" required />
              </div>
              <div class="mb-3">
                <label class="form-label">Nombre</label>
                <input type="text" class="form-control" v-model="form.nombre" required />
              </div>
              <div class="mb-3">
                <label class="form-label">Categoría</label>
                <input type="text" class="form-control" v-model="form.categoria" required />
              </div>
              <div class="mb-3">
                <label class="form-label">Precio (Q)</label>
                <input type="number" step="0.01" class="form-control" v-model.number="form.precio" required />
              </div>
              <div class="mb-3">
                <label class="form-label">Stock</label>
                <input type="number" class="form-control" v-model.number="form.stock" required />
              </div>
              <div class="text-end">
                <button type="button" class="btn btn-secondary me-2" @click="cerrarModal">Cancelar</button>
                <button type="submit" class="btn btn-success">Guardar</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import api from '../services/api'

export default {
  name: 'InventarioView',
  data() {
    return {
      productos: [],
      mostrarModal: false,
      editando: false,
      form: { id: null, sku: '', nombre: '', categoria: '', precio: 0, stock: 0 }
    }
  },
  mounted() {
    this.cargarProductos()
  },
  methods: {
    async cargarProductos() {
      try {
        const res = await api.get('/productos')
        this.productos = res.data
      } catch (err) {
        console.error('Error cargando inventario:', err)
      }
    },
    abrirModalCrear() {
      this.editando = false
      this.form = { id: null, sku: '', nombre: '', categoria: '', precio: 0, stock: 0 }
      this.mostrarModal = true
    },
    abrirModalEditar(prod) {
      this.editando = true
      this.form = { ...prod }
      this.mostrarModal = true
    },
    cerrarModal() {
      this.mostrarModal = false
    },
    async guardarProducto() {
      try {
        if (this.editando) {
          await api.put(`/productos/${this.form.id}`, this.form)
        } else {
          await api.post('/productos', this.form)
        }
        this.cerrarModal()
        this.cargarProductos()
      } catch (err) {
        console.error('Error al guardar producto:', err)
      }
    },
    async eliminarProducto(id) {
      if (confirm('¿Estás seguro de eliminar este producto?')) {
        try {
          await api.delete(`/productos/${id}`)
          this.cargarProductos()
        } catch (err) {
          console.error('Error al eliminar:', err)
        }
      }
    }
  }
}
</script>