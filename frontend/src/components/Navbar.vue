<template>
  <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container-fluid">
      <router-link class="navbar-brand" to="/">El Quetzal</router-link>
      <div class="collapse navbar-collapse">
        <ul class="navbar-nav me-auto mb-2 mb-lg-0">
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
</template>

<script>
export default {
  name: 'Navbar'
}
</script>