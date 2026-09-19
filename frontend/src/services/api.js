import axios from 'axios'

const api = axios.create({
  baseURL: '/api', // Vite redirige esto internamente a Flask
  headers: {
    'Content-Type': 'application/json'
  }
})

export default api