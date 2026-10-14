#!/usr/bin/env bash
# ==============================================================================
# PROYECTO 2 — VIRTUALIZACIÓN — EQUIPO VIRTUAL INSANITY (EL QUETZAL)
# ROL 5: Orquestación, Evidencia y Documentación
# SCRIPT: push-images.sh
# DESCRIPCIÓN: Publica en Docker Hub únicamente las imágenes locales previamente
#              construidas, con los tags exactos declarados en los manifiestos k8s.
# ==============================================================================

set -euo pipefail

# 1. Resolución robusta del directorio raíz del repositorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colores para salida en consola
CLR_RESET="\033[0m"
CLR_INFO="\033[1;34m"
CLR_SUCCESS="\033[1;32m"
CLR_WARN="\033[1;33m"
CLR_ERROR="\033[1;31m"

log_info() { echo -e "${CLR_INFO}[INFO]${CLR_RESET} $1"; }
log_success() { echo -e "${CLR_SUCCESS}[OK]${CLR_RESET} $1"; }
log_warn() { echo -e "${CLR_WARN}[ADVERTENCIA]${CLR_RESET} $1"; }
log_error() { echo -e "${CLR_ERROR}[ERROR]${CLR_RESET} $1" >&2; }

# Función de ayuda
mostrar_ayuda() {
    cat <<EOF
Uso: $0 [all|gateway|catalogo|inventario|clientes|pedidos|reportes|frontend] [--yes|-y]

Publica en Docker Hub las imágenes previamente construidas para el Proyecto 2.

Argumentos:
  all         Publica las 7 imágenes personalizadas (predeterminado)
  gateway     Publica virtual4insanity/elquetzal-gateway:2.0
  catalogo    Publica virtual4insanity/elquetzal-catalogo:2.0
  inventario  Publica virtual4insanity/elquetzal-inventario:2.0
  clientes    Publica virtual4insanity/elquetzal-clientes:1.0
  pedidos     Publica virtual4insanity/elquetzal-pedidos:2.1
  reportes    Publica virtual4insanity/elquetzal-reportes:1.0
  frontend    Publica virtual4insanity/elquetzal-frontend:2.2
  -y, --yes   Omite la solicitud interactiva de confirmación
  -h, --help  Muestra este mensaje de ayuda y termina con éxito

ADVERTENCIA:
  La publicación requiere una sesión activa mediante 'docker login' y permisos en
  el namespace 'virtual4insanity'. Se solicitará confirmación explícita del usuario
  antes de iniciar cualquier transferencia a la red.
EOF
}

# 2. Matriz de imágenes declaradas en Kubernetes
# Componente | Imagen y Tag Oficial
DECLARACIONES=(
    "gateway|virtual4insanity/elquetzal-gateway:2.0"
    "catalogo|virtual4insanity/elquetzal-catalogo:2.0"
    "inventario|virtual4insanity/elquetzal-inventario:2.0"
    "clientes|virtual4insanity/elquetzal-clientes:1.0"
    "pedidos|virtual4insanity/elquetzal-pedidos:2.1"
    "reportes|virtual4insanity/elquetzal-reportes:1.0"
    "frontend|virtual4insanity/elquetzal-frontend:2.2"
)

# 3. Procesamiento y validación temprana de argumentos
OBJETIVO="all"
AUTO_CONFIRM=false

for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            ;;
        *)
            OBJETIVO="${arg}"
            ;;
    esac
done

COMPONENTES_VALIDOS=("all" "gateway" "catalogo" "inventario" "clientes" "pedidos" "reportes" "frontend")
ARGUMENTO_VALIDO=false
for c in "${COMPONENTES_VALIDOS[@]}"; do
    if [[ "${OBJETIVO}" == "${c}" ]]; then
        ARGUMENTO_VALIDO=true
        break
    fi
done

if [[ "${ARGUMENTO_VALIDO}" == false ]]; then
    log_error "Componente no reconocido: '${OBJETIVO}'"
    echo "Uso: $0 [all|gateway|catalogo|inventario|clientes|pedidos|reportes|frontend] [--yes|-y] (o -h para ayuda)"
    exit 1
fi

# 4. Verificación de dependencias del entorno
if ! command -v docker >/dev/null 2>&1; then
    log_error "El comando 'docker' no se encuentra disponible en el PATH."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "No se puede establecer conexión con el daemon de Docker."
    exit 1
fi

# 5. Filtrar componentes a publicar
declare -a IMAGENES_A_PUBLICAR=()

if [[ "${OBJETIVO}" == "all" ]]; then
    for item in "${DECLARACIONES[@]}"; do
        IFS="|" read -r c_name c_tag <<< "${item}"
        IMAGENES_A_PUBLICAR+=("${c_tag}")
    done
else
    for item in "${DECLARACIONES[@]}"; do
        IFS="|" read -r c_name c_tag <<< "${item}"
        if [[ "${c_name}" == "${OBJETIVO}" ]]; then
            IMAGENES_A_PUBLICAR+=("${c_tag}")
            break
        fi
    done
fi

# 6. Verificación previa de existencia local
echo "============================================================"
echo " El Quetzal — Publicación de Imágenes a Docker Hub"
echo " Namespace: virtual4insanity | Orquestador: Kubernetes (k3s)"
echo "============================================================"

log_info "Verificando disponibilidad local de las imágenes objetivo..."
FALTANTES=0

for img in "${IMAGENES_A_PUBLICAR[@]}"; do
    if docker image inspect "${img}" >/dev/null 2>&1; then
        log_success "Disponible localmente: ${img}"
    else
        log_error "No encontrada localmente: ${img}"
        FALTANTES=$((FALTANTES + 1))
    fi
done

if [[ ${FALTANTES} -gt 0 ]]; then
    log_error "Hay ${FALTANTES} imagen(es) que no existen en el Docker local."
    log_error "Ejecute previamente 'build-images.sh' para construirlas antes de publicar."
    exit 1
fi

# 7. Alertas de seguridad sobre tags existentes (Riesgo de sobrescritura)
for img in "${IMAGENES_A_PUBLICAR[@]}"; do
    if [[ "${img}" == "virtual4insanity/elquetzal-gateway:1.0" ]]; then
        log_warn "ALERTA DE TAG: '${img}' coincide con la versión histórica publicada del Proyecto 1."
        log_warn "En el Proyecto 1, gateway:1.0 incluía el frontend Vue integrado. En Proyecto 2, el frontend es independiente."
        log_warn "Sobrescribir :1.0 modificará el comportamiento de despliegues históricos basados en Docker Compose."
    elif [[ "${img}" == "virtual4insanity/elquetzal-gateway:2.0" ]]; then
        log_info "Verificación de gateway:2.0: corresponde a la versión de Kubernetes que enruta '/' hacia el Service frontend."
    fi
done

# 8. Confirmación explícita del usuario
echo ""
log_warn "Se van a publicar ${#IMAGENES_A_PUBLICAR[@]} imagen(es) al registro público de Docker Hub:"
for img in "${IMAGENES_A_PUBLICAR[@]}"; do
    echo "  - ${img}"
done
echo ""

if [[ "${AUTO_CONFIRM}" != true ]]; then
    read -r -p "¿Desea proceder con la publicación a Docker Hub? [s/N]: " RESPUESTA
    case "${RESPUESTA}" in
        [sS]|[sS][iI]|[yY]|[yY][eE][sS])
            log_info "Confirmación recibida. Procediendo con la publicación..."
            ;;
        *)
            log_info "Operación cancelada por el usuario. No se publicó ninguna imagen."
            exit 0
            ;;
    esac
fi

# 9. Publicación secuencial
for img in "${IMAGENES_A_PUBLICAR[@]}"; do
    log_info "Publicando: ${img} ..."
    if docker push "${img}"; then
        log_success "Publicada exitosamente: ${img}"
    else
        log_error "Falló la publicación de: ${img}"
        log_error "Asegúrese de haber iniciado sesión con 'docker login' y tener permisos en 'virtual4insanity'."
        exit 1
    fi
done

echo ""
log_success "Todas las imágenes seleccionadas fueron publicadas exitosamente en Docker Hub."
