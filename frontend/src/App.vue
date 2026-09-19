<template>
  <div id="app">
    <!-- Barra de navegación superior -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-success shadow-sm mb-4">
      <div class="container-fluid">
        <router-link class="navbar-brand fw-bold" to="/">El Quetzal - Sistema</router-link>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
          <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="navbarNav">
          <ul class="navbar-nav ms-auto">
            <li class="nav-item">
              <router-link class="nav-link" to="/">Dashboard</router-link>
            </li>
            <li class="nav-item">
              <router-link class="nav-link" to="/inventario">Inventario</router-link>
            </li>
            <li class="nav-item">
              <router-link class="nav-link" to="/pedidos">Pedidos</router-link>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <!-- Vista activa -->
    <router-view />
  </div>
</template>

<script>
export default {
  name: 'App'
}
</script>