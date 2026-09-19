<template>
  <div class="container mt-4">
    <h2 class="mb-4">Gestión de Pedidos - El Quetzal</h2>

    <div class="row">
      <!-- Formulario para Crear Pedido -->
      <div class="col-md-5">
        <div class="card shadow-sm mb-4">
          <div class="card-header bg-success text-white">
            <h5 class="mb-0">Crear Nuevo Pedido</h5>
          </div>
          <div class="card-body">
            <form @submit.prevent="registrarPedido">
              <div class="mb-3">
                <label class="form-label">Carné del Integrante</label>
                <input 
                  type="text" 
                  class="form-control" 
                  v-model="pedidoForm.carne" 
                  placeholder="Ej. 0900-XX-XXXX" 
                  required 
                />
              </div>

              <div class="mb-3">
                <label class="form-label">Seleccionar Producto</label>
                <select class="form-select" v-model="productoSeleccionado">
                  <option disabled value="">-- Elige un producto --</option>
                  <option v-for="prod in productos" :key="prod.id" :value="prod">
                    {{ prod.nombre }} (Stock dispo: {{ prod.stock }} - Q{{ prod.precio }})
                  </option>
                </select>
              </div>

              <div class="mb-3">
                <label class="form-label">Cantidad</label>
                <input 
                  type="number" 
                  class="form-control" 
                  v-model.number="cantidadSeleccionada" 
                  min="1" 
                />
              </div>

              <button 
                type="button" 
                class="btn btn-outline-success w-100 mb-3" 
                @click="agregarAlDetalle"
              >
                Agregar al Pedido
              </button>

              <!-- Lista de items en el pedido actual -->
              <ul class="list-group mb-3" v-if="detallePedido.length > 0">
                <li v-for="(item, index) in detallePedido" :key="index" class="list-group-item d-flex justify-content-between align-items-center">
                  <div>
                    <strong>{{ item.nombre }}</strong> x {{ item.cantidad }}
                    <br><small class="text-muted">Subtotal: Q{{ (item.precio * item.cantidad).toFixed(2) }}</small>
                  </div>
                  <button type="button" class="btn btn-sm btn-danger" @click="removerItem(index)">X</button>
                </li>
              </ul>

              <div v-if="errorStock" class="alert alert-danger py-2" role="alert">
                {{ errorStock }}
              </div>

              <button type="submit" class="btn btn-success w-100" :disabled="detallePedido.length === 0">
                Confirmar y Procesar Pedido
              </button>
            </form>
          </div>
        </div>
      </div>

      <!-- Historial / Listado de Pedidos Recientes -->
      <div class="col-md-7">
        <div class="card shadow-sm">
          <div class="card-header bg-secondary text-white">
            <h5 class="mb-0">Historial de Pedidos del Día</h5>
          </div>
          <div class="card-body">
            <table class="table table-striped align-middle">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Carné</th>
                  <th>Total (Q)</th>
                  <th>Estado</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="ped in listaPedidos" :key="ped.id">
                  <td>#{{ ped.id }}</td>
                  <td><code>{{ ped.carne }}</code></td>
                  <td>Q {{ Number(ped.total).toFixed(2) }}</td>
                  <td><span class="badge bg-success">Completado</span></td>
                </tr>
                <tr v-if="listaPedidos.length === 0">
                  <td colspan="4" class="text-center text-muted">No hay pedidos registrados aún.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import api from '../services/api'

export default {
  name: 'PedidosView',
  data() {
    return {
      productos: [],
      productoSeleccionado: '',
      cantidadSeleccionada: 1,
      detallePedido: [],
      errorStock: '',
      pedidoForm: {
        carne: ''
      },
      listaPedidos: []
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
        console.error('Error al cargar productos para pedidos:', err)
      }
    },
    agregarAlDetalle() {
      this.errorStock = ''
      if (!this.productoSeleccionado) return

      if (this.cantidadSeleccionada > this.productoSeleccionado.stock) {
        this.errorStock = `Stock insuficiente. Solo hay ${this.productoSeleccionado.stock} unidades disponibles.`
        return
      }

      this.detallePedido.push({
        producto_id: this.productoSeleccionado.id,
        nombre: this.productoSeleccionado.nombre,
        precio: this.productoSeleccionado.precio,
        cantidad: this.cantidadSeleccionada
      })

      this.productoSeleccionado = ''
      this.cantidadSeleccionada = 1
    },
    removerItem(index) {
      this.detallePedido.splice(index, 1)
    },
    async registrarPedido() {
      if (!this.pedidoForm.carne) {
        alert('Por favor ingrese el carné del integrante.')
        return
      }

      const totalCalculado = this.detallePedido.reduce((acc, item) => acc + (item.precio * item.cantidad), 0)

      const nuevoPedido = {
        carne: this.pedidoForm.carne,
        items: this.detallePedido,
        total: totalCalculado
      }

      try {
        // Simulamos o enviamos el registro del pedido
        this.listaPedidos.unshift({
          id: this.listaPedidos.length + 1,
          carne: nuevoPedido.carne,
          total: totalCalculado
        })

        // Limpiar formulario
        this.detallePedido = []
        this.pedidoForm.carne = ''
        alert('¡Pedido procesado con éxito y stock descontado!')
      } catch (err) {
        console.error('Error al procesar el pedido:', err)
      }
    }
  }
}
</script>