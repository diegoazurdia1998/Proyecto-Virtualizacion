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
                <label class="form-label">Cliente</label>
                <select class="form-select" v-model.number="pedidoForm.cliente_id" required>
                  <option disabled value="">-- Elige un cliente --</option>
                  <option v-for="c in clientes" :key="c.id" :value="c.id">
                    {{ c.nombre }} ({{ c.nit }})
                  </option>
                </select>
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

              <div v-if="mensajeOk" class="alert alert-success py-2" role="alert">
                {{ mensajeOk }}
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
                <tr v-for="ped in listaPedidos" :key="ped.pedido_id">
                  <td>#{{ ped.pedido_id }}</td>
                  <td><code>{{ ped.carne }}</code></td>
                  <td>Q {{ Number(ped.total).toFixed(2) }}</td>
                  <td><span class="badge bg-success">{{ ped.estado }}</span></td>
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
      clientes: [],
      productoSeleccionado: '',
      cantidadSeleccionada: 1,
      detallePedido: [],
      errorStock: '',
      mensajeOk: '',
      pedidoForm: {
        carne: '',
        cliente_id: ''
      },
      listaPedidos: []
    }
  },
  mounted() {
    this.cargarProductos()
    this.cargarClientes()
    this.cargarPedidos()
  },
  methods: {
    async cargarProductos() {
      try {
        const res = await api.get('/inventario/productos')
        this.productos = res.data
      } catch (err) {
        console.error('Error al cargar productos para pedidos:', err)
      }
    },
    async cargarClientes() {
      try {
        const res = await api.get('/clientes/clientes')
        this.clientes = res.data
      } catch (err) {
        console.error('Error al cargar clientes:', err)
      }
    },
    async cargarPedidos() {
      try {
        const res = await api.get('/pedidos/pedidos')
        this.listaPedidos = res.data
      } catch (err) {
        console.error('Error al cargar el historial de pedidos:', err)
      }
    },
    agregarAlDetalle() {
      this.errorStock = ''
      this.mensajeOk = ''
      if (!this.productoSeleccionado) return

      const prod = this.productoSeleccionado
      const existente = this.detallePedido.find(i => i.sku === prod.sku)
      const yaEnPedido = existente ? existente.cantidad : 0

      if (yaEnPedido + this.cantidadSeleccionada > prod.stock) {
        this.errorStock = `Stock insuficiente. Hay ${prod.stock} unidades y el pedido ya lleva ${yaEnPedido}.`
        return
      }

      if (existente) {
        existente.cantidad += this.cantidadSeleccionada
      } else {
        this.detallePedido.push({
          sku: prod.sku,
          nombre: prod.nombre,
          precio: prod.precio,
          cantidad: this.cantidadSeleccionada
        })
      }

      this.productoSeleccionado = ''
      this.cantidadSeleccionada = 1
    },
    
    removerItem(index) {
      this.detallePedido.splice(index, 1)
    },
    async registrarPedido() {
      this.errorStock = ''
      this.mensajeOk = ''

      if (!this.pedidoForm.carne || !this.pedidoForm.cliente_id) {
        this.errorStock = 'Ingrese el carné del integrante y seleccione un cliente.'
        return
      }

      // El total no se envía: lo calcula el servicio con el precio real de la base.
      const nuevoPedido = {
        carne: this.pedidoForm.carne,
        cliente_id: this.pedidoForm.cliente_id,
        items: this.detallePedido.map(i => ({ sku: i.sku, cantidad: i.cantidad }))
      }

      try {
        const res = await api.post('/pedidos/pedidos', nuevoPedido)
        this.mensajeOk = `Pedido #${res.data.pedido_id} confirmado por Q${Number(res.data.total).toFixed(2)}. Stock descontado.`

        this.detallePedido = []
        this.pedidoForm.carne = ''
        this.pedidoForm.cliente_id = ''

        await this.cargarPedidos()
        await this.cargarProductos()
      } catch (err) {
        const data = err.response ? err.response.data : null

        if (data && data.error === 'stock_insuficiente') {
          const faltantes = data.detalle
            .map(d => `${d.sku}: pidió ${d.solicitado}, hay ${d.disponible}`)
            .join(' · ')
          this.errorStock = `Pedido rechazado por stock insuficiente. ${faltantes}`
        } else {
          this.errorStock = 'No se pudo registrar el pedido. Revise la consola para el detalle.'
        }
        console.error('Error al procesar el pedido:', err)
      }
    }
  }
}
</script>