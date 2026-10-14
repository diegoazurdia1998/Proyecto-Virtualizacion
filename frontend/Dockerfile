# Frontend Vue - El Quetzal - Equipo virtual4insanity (Rol 4)
# Etapa 1: compila Vue con Node
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Etapa 2: nginx sirve solo los archivos compilados
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80