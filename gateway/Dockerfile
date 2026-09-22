# Etapa 1: build de producción del frontend Vue
FROM node:20-alpine AS build-frontend
WORKDIR /app
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# Etapa 2: nginx sirviendo el build + gateway hacia los microservicios
FROM nginx:1.27-alpine
COPY gateway/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build-frontend /app/dist /usr/share/nginx/html
EXPOSE 80
