#!/usr/bin/env bash
# ==============================================================================
# PROYECTO 2 — VIRTUALIZACIÓN — EQUIPO VIRTUAL INSANITY (EL QUETZAL)
# ROL 5: Orquestación, Evidencia y Documentación
# SCRIPT: build-images.sh
# DESCRIPCIÓN: Construye las imágenes Docker personalizadas requeridas por los
#              manifiestos de Kubernetes (k3s), usando sus contextos y Dockerfiles.
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
Uso: $0 [all|gateway|catalogo|inventario|clientes|pedidos|reportes|frontend]

Construye las imágenes Docker personalizadas para el Proyecto 2 (Kubernetes/k3s)
utilizando sus Dockerfiles y contextos de construcción específicos.

Argumentos:
  all         Construye las 7 imágenes personalizadas (predeterminado)
  gateway     Construye virtual4insanity/elquetzal-gateway:2.0
  catalogo    Construye virtual4insanity/elquetzal-catalogo:2.0
  inventario  Construye virtual4insanity/elquetzal-inventario:2.0
  clientes    Construye virtual4insanity/elquetzal-clientes:1.0
  pedidos     Construye virtual4insanity/elquetzal-pedidos:2.1
  reportes    Construye virtual4insanity/elquetzal-reportes:1.0
  frontend    Construye virtual4insanity/elquetzal-frontend:2.2
  -h, --help  Muestra este mensaje de ayuda y termina con éxito

Nota: La imagen de PostgreSQL (postgres:16-alpine) es oficial y se excluye de la compilación.
EOF
}

# 2. Matriz de imágenes declaradas en Kubernetes
# Componente | Imagen y Tag Oficial | Contexto de Construcción | Dockerfile
# NOTA: PostgreSQL (postgres:16-alpine) se excluye deliberadamente al ser imagen oficial pública.
DECLARACIONES=(
    "gateway|virtual4insanity/elquetzal-gateway:2.0|gateway|gateway/Dockerfile"
    "catalogo|virtual4insanity/elquetzal-catalogo:2.0|backend/catalogo|backend/catalogo/Dockerfile"
    "inventario|virtual4insanity/elquetzal-inventario:2.0|backend/inventario|backend/inventario/Dockerfile"
    "clientes|virtual4insanity/elquetzal-clientes:1.0|backend/clientes|backend/clientes/Dockerfile"
    "pedidos|virtual4insanity/elquetzal-pedidos:2.1|backend/pedidos|backend/pedidos/Dockerfile"
    "reportes|virtual4insanity/elquetzal-reportes:1.0|backend/reportes|backend/reportes/Dockerfile"
    "frontend|virtual4insanity/elquetzal-frontend:2.2|frontend|frontend/Dockerfile"
)

# 3. Procesamiento y validación temprana de argumentos
OBJETIVO="${1:-all}"

if [[ "${OBJETIVO}" == "-h" || "${OBJETIVO}" == "--help" ]]; then
    mostrar_ayuda
    exit 0
fi

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
    echo "Uso: $0 [all|gateway|catalogo|inventario|clientes|pedidos|reportes|frontend] (o -h para ayuda)"
    exit 1
fi

# 4. Verificación de dependencias del entorno
if ! command -v docker >/dev/null 2>&1; then
    log_error "El comando 'docker' no se encuentra disponible en el PATH."
    log_error "Instale Docker Engine o asegúrese de que el binario sea accesible."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "No se puede establecer conexión con el daemon de Docker."
    log_error "Asegúrese de que el servicio de Docker esté activo y el usuario tenga permisos."
    exit 1
fi

construir_componente() {
    local comp="$1"
    local tag="$2"
    local ctx_rel="$3"
    local df_rel="$4"

    local ctx_abs="${REPO_ROOT}/${ctx_rel}"
    local df_abs="${REPO_ROOT}/${df_rel}"

    log_info "------------------------------------------------------------"
    log_info "Componente         : ${comp}"
    log_info "Imagen objetivo    : ${tag}"
    log_info "Contexto           : ${ctx_abs}"
    log_info "Dockerfile         : ${df_abs}"

    if [[ ! -d "${ctx_abs}" ]]; then
        log_error "El directorio de contexto no existe: ${ctx_abs}"
        return 1
    fi

    if [[ ! -f "${df_abs}" ]]; then
        log_error "El archivo Dockerfile no existe: ${df_abs}"
        return 1
    fi

    log_info "Iniciando compilación..."
    docker build \
        -t "${tag}" \
        -f "${df_abs}" \
        "${ctx_abs}"

    log_success "Imagen construida correctamente: ${tag}"
}

# 5. Flujo de compilación
echo "============================================================"
echo " El Quetzal — Compilación de Imágenes Docker (Proyecto 2)"
echo " Namespace: virtual4insanity | Orquestador: Kubernetes (k3s)"
echo "============================================================"

if [[ "${OBJETIVO}" == "all" ]]; then
    log_info "Compilando todas las imágenes personalizadas (${#DECLARACIONES[@]} componentes)..."
    for item in "${DECLARACIONES[@]}"; do
        IFS="|" read -r c_name c_tag c_ctx c_df <<< "${item}"
        construir_componente "${c_name}" "${c_tag}" "${c_ctx}" "${c_df}"
    done
    echo ""
    log_success "Proceso de compilación completado para todos los componentes."
else
    for item in "${DECLARACIONES[@]}"; do
        IFS="|" read -r c_name c_tag c_ctx c_df <<< "${item}"
        if [[ "${c_name}" == "${OBJETIVO}" ]]; then
            construir_componente "${c_name}" "${c_tag}" "${c_ctx}" "${c_df}"
            break
        fi
    done
fi
