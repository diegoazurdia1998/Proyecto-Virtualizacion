#!/usr/bin/env bash
# ==============================================================================
# PROYECTO 2 — VIRTUALIZACIÓN — EQUIPO VIRTUAL INSANITY (EL QUETZAL)
# ROL 5: Orquestación, Evidencia y Documentación
# SCRIPT: verificar-imagenes.sh
# DESCRIPCIÓN: Diagnóstico no destructivo que extrae dinámicamente las imágenes
#              y tags de los manifiestos Kubernetes, detecta discrepancias reales
#              contra los scripts de build/push y valida archivos en disco y Docker.
# ==============================================================================

set -euo pipefail

# 1. Resolución robusta del directorio raíz del repositorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colores para salida en consola
CLR_RESET="\033[0m"
CLR_HEADER="\033[1;36m"
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
Uso: $0 [-h|--help]

Diagnóstico de solo lectura y no destructivo del Proyecto 2 (Kubernetes / k3s).
Extrae dinámicamente las imágenes declaradas en los manifiestos YAML y detecta
discrepancias contra los scripts de build/push, verificando además la existencia
de Dockerfiles en disco y el estado del daemon local de Docker.

No requiere argumentos y no realiza ninguna acción destructiva ni de compilación.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    mostrar_ayuda
    exit 0
fi

# 2. Verificación de Docker local
DOCKER_DISPONIBLE=false
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        DOCKER_DISPONIBLE=true
    fi
fi

# 3. Funciones de extracción dinámica
extraer_imagen_manifiesto() {
    local comp="$1"
    local manif_rel="$2"
    local manif_abs="${REPO_ROOT}/${manif_rel}"
    local img=""

    if [[ ! -f "${manif_abs}" ]]; then
        echo "MANIFIESTO_NO_ENCONTRADO"
        return
    fi

    case "${comp}" in
        gateway)
            img=$(grep -E '^[[:space:]]*image:[[:space:]]*virtual4insanity/elquetzal-gateway:' "${manif_abs}" | sed -E 's/^[[:space:]]*image:[[:space:]]*//' | head -n 1)
            ;;
        frontend)
            img=$(grep -E '^[[:space:]]*image:[[:space:]]*virtual4insanity/elquetzal-frontend:' "${manif_abs}" | sed -E 's/^[[:space:]]*image:[[:space:]]*//' | head -n 1)
            ;;
        db)
            img=$(grep -E '^[[:space:]]*image:[[:space:]]*postgres:' "${manif_abs}" | sed -E 's/^[[:space:]]*image:[[:space:]]*//' | head -n 1)
            ;;
        catalogo|inventario|clientes|pedidos|reportes)
            img=$(grep -E "^[[:space:]]*image:[[:space:]]*virtual4insanity/elquetzal-${comp}:" "${manif_abs}" | sed -E 's/^[[:space:]]*image:[[:space:]]*//' | head -n 1)
            ;;
    esac

    # Si no hubo coincidencia específica, buscar cualquier línea de image con el nombre
    if [[ -z "${img}" ]]; then
        img=$(grep -E "image:.*${comp}" "${manif_abs}" | sed -E 's/^[[:space:]]*image:[[:space:]]*//' | head -n 1 || true)
    fi

    echo "${img:-NO_DECLARADA}"
}

extraer_imagen_script() {
    local comp="$1"
    if [[ "${comp}" == "db" ]]; then
        echo "postgres:16-alpine"
        return
    fi

    local build_script="${REPO_ROOT}/k8s/scripts/build-images.sh"
    if [[ -f "${build_script}" ]]; then
        local line
        line=$(grep -E "^[[:space:]]*\"${comp}\|" "${build_script}" | head -n 1 || true)
        if [[ -n "${line}" ]]; then
            echo "${line}" | cut -d'|' -f2
            return
        fi
    fi
    echo "NO_CONFIGURADA"
}

# 4. Matriz de Componentes del Proyecto 2
# COMPONENTE | MANIFIESTO_ORIGEN | CONTEXTO | DOCKERFILE | ES_OFICIAL
COMPONENTES=(
    "gateway|k8s/gateway-deployment.yaml|gateway|gateway/Dockerfile|false"
    "catalogo|k8s/backend-deployment.yaml|backend/catalogo|backend/catalogo/Dockerfile|false"
    "inventario|k8s/backend-deployment.yaml|backend/inventario|backend/inventario/Dockerfile|false"
    "clientes|k8s/backend-deployment.yaml|backend/clientes|backend/clientes/Dockerfile|false"
    "pedidos|k8s/backend-deployment.yaml|backend/pedidos|backend/pedidos/Dockerfile|false"
    "reportes|k8s/backend-deployment.yaml|backend/reportes|backend/reportes/Dockerfile|false"
    "frontend|k8s/frontend-deployment.yaml|frontend|frontend/Dockerfile|false"
    "db|k8s/db-deployment.yaml|N/A|N/A (Oficial)|true"
)

echo "===================================================================================================="
echo -e "${CLR_HEADER} El Quetzal — Verificación y Conciliación Dinámica de Imágenes Docker (Proyecto 2)${CLR_RESET}"
echo " Repositorio: ${REPO_ROOT}"
echo " Daemon Docker: $(if [[ "${DOCKER_DISPONIBLE}" == true ]]; then echo -e "${CLR_SUCCESS}Activo y accesible${CLR_RESET}"; else echo -e "${CLR_WARN}No accesible o inactivo (se omitirá inspección de binarios locales)${CLR_RESET}"; fi)"
echo "===================================================================================================="
echo ""

TOTAL_DECLARADAS=0
TOTAL_DF_VALIDOS=0
TOTAL_LOCALES_PRESENTES=0
TOTAL_SINCRONIZADAS=0
TOTAL_DISCREPANCIAS=0
declare -a LISTA_DISCREPANCIAS=()

printf "%-11s | %-41s | %-20s | %-13s | %-14s\n" "COMPONENTE" "IMAGEN MANIFIESTO (K8S)" "CONCILIACIÓN SCRIPT" "DOCKERFILE" "DOCKER LOCAL"
printf "%-11s-+-%-41s-+-%-20s-+-%-13s-+-%-14s\n" "-----------" "-----------------------------------------" "--------------------" "-------------" "--------------"

for item in "${COMPONENTES[@]}"; do
    IFS="|" read -r comp manif ctx df oficial <<< "${item}"
    TOTAL_DECLARADAS=$((TOTAL_DECLARADAS + 1))

    # Extracción dinámica
    IMG_MANIF=$(extraer_imagen_manifiesto "${comp}" "${manif}")
    IMG_SCRIPT=$(extraer_imagen_script "${comp}")

    # Conciliación entre manifiesto y scripts
    ESTADO_CONCIL="No verificado"
    if [[ "${oficial}" == "true" ]]; then
        ESTADO_CONCIL="Oficial (Excluido)"
    else
        if [[ "${IMG_MANIF}" == "${IMG_SCRIPT}" ]]; then
            ESTADO_CONCIL="Coincide (OK)"
            TOTAL_SINCRONIZADAS=$((TOTAL_SINCRONIZADAS + 1))
        else
            ESTADO_CONCIL="DISCREPANCIA"
            TOTAL_DISCREPANCIAS=$((TOTAL_DISCREPANCIAS + 1))
            LISTA_DISCREPANCIAS+=("${comp}: K8s=[${IMG_MANIF}] != Script=[${IMG_SCRIPT}]")
        fi
    fi

    # Validación de Dockerfile y contexto en disco
    ESTADO_DF="No requerido"
    if [[ "${oficial}" == "false" ]]; then
        DF_PATH="${REPO_ROOT}/${df}"
        CTX_PATH="${REPO_ROOT}/${ctx}"
        if [[ -f "${DF_PATH}" && -d "${CTX_PATH}" ]]; then
            ESTADO_DF="Existe (OK)"
            TOTAL_DF_VALIDOS=$((TOTAL_DF_VALIDOS + 1))
        elif [[ ! -f "${DF_PATH}" ]]; then
            ESTADO_DF="DF faltante"
        else
            ESTADO_DF="Ctx faltante"
        fi
    else
        ESTADO_DF="Oficial (Hub)"
        TOTAL_DF_VALIDOS=$((TOTAL_DF_VALIDOS + 1))
    fi

    # Validación de existencia local en Docker
    ESTADO_LOCAL="No verificado"
    if [[ "${DOCKER_DISPONIBLE}" == true ]]; then
        if docker image inspect "${IMG_MANIF}" >/dev/null 2>&1; then
            IMG_ID=$(docker image inspect --format='{{slice .Id 7 19}}' "${IMG_MANIF}" 2>/dev/null || echo "presente")
            ESTADO_LOCAL="Presente (${IMG_ID})"
            TOTAL_LOCALES_PRESENTES=$((TOTAL_LOCALES_PRESENTES + 1))
        else
            ESTADO_LOCAL="Ausente"
        fi
    else
        ESTADO_LOCAL="Daemon inactivo"
    fi

    printf "%-11s | %-41s | %-20s | %-13s | %-14s\n" "${comp}" "${IMG_MANIF}" "${ESTADO_CONCIL}" "${ESTADO_DF}" "${ESTADO_LOCAL}"
done

echo ""
echo "===================================================================================================="
echo " RESUMEN DIAGNÓSTICO DE CONCILIACIÓN:"
echo " - Total de componentes analizados                    : ${TOTAL_DECLARADAS}"
echo " - Sincronizados entre manifiestos K8s y scripts      : ${TOTAL_SINCRONIZADAS} de 7 personalizados"
echo " - Discrepancias detectadas                           : ${TOTAL_DISCREPANCIAS}"
echo " - Archivos Dockerfile y contextos verificados en disco: ${TOTAL_DF_VALIDOS} de ${TOTAL_DECLARADAS}"
if [[ "${DOCKER_DISPONIBLE}" == true ]]; then
    echo " - Imágenes disponibles en el Docker local             : ${TOTAL_LOCALES_PRESENTES} de ${TOTAL_DECLARADAS}"
else
    echo " - Imágenes en Docker local                             : Requiere daemon de Docker activo"
fi
echo "===================================================================================================="

if [[ ${TOTAL_DISCREPANCIAS} -gt 0 ]]; then
    echo ""
    log_warn "Se detectaron ${TOTAL_DISCREPANCIAS} discrepancia(s) entre manifiestos K8s y scripts:"
    for disc in "${LISTA_DISCREPANCIAS[@]}"; do
        echo "  - ${disc}"
    done
else
    echo ""
    log_success "Todos los componentes personalizados están 100% sincronizados entre manifiestos y scripts."
fi

echo ""
log_info "Notas de trazabilidad y compatibilidad:"
echo "  1. La imagen 'postgres:16-alpine' es oficial y se excluye deliberadamente de compilación y push."
echo "  2. Las etiquetas actuales coinciden con las versiones de producción de Kubernetes:"
echo "     - gateway:2.0    : Nginx configurado para reenviar '/' hacia el Service ClusterIP 'frontend:80'."
echo "     - catalogo:2.0   : API con endpoint '/equipo' ordenado y preparado para UI."
echo "     - inventario:2.0 : Control atómico de stock con validación de umbral."
echo "     - clientes:1.0   : Directorio y validación de clientes mayoristas."
echo "     - pedidos:2.1    : Orquestación transaccional con validación de carné del equipo y detalle de productos."
echo "     - reportes:1.0   : Métricas de negocio y stock crítico."
echo "     - frontend:2.2   : SPA Vue con selector dinámico de integrantes y visualización de pedidos."
