#!/usr/bin/env bash
# ==============================================================================
# PROYECTO 2 — VIRTUALIZACIÓN — EQUIPO VIRTUAL INSANITY (EL QUETZAL)
# ROL 5: Orquestación, Evidencia y Documentación
# SCRIPT: verificar-k8s.sh
# DESCRIPCIÓN: Diagnóstico no destructivo y de solo lectura del estado del
#              despliegue en Kubernetes (k3s). Verifica contexto de ejecución,
#              namespace, PVC, ConfigMaps, Secrets (sin revelar valores),
#              Deployments, réplicas, Pods, Services y Endpoints.
# ==============================================================================

set -euo pipefail

# 1. Resolución robusta del directorio raíz del repositorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colores para salida en consola (se desactivan si no es terminal interactiva)
if [[ -t 1 ]]; then
    CLR_RESET="\033[0m"
    CLR_HEADER="\033[1;36m"
    CLR_INFO="\033[1;34m"
    CLR_SUCCESS="\033[1;32m"
    CLR_WARN="\033[1;33m"
    CLR_ERROR="\033[1;31m"
    CLR_BOLD="\033[1m"
else
    CLR_RESET=""
    CLR_HEADER=""
    CLR_INFO=""
    CLR_SUCCESS=""
    CLR_WARN=""
    CLR_ERROR=""
    CLR_BOLD=""
fi

log_info()    { echo -e "${CLR_INFO}[INFO]${CLR_RESET} $1"; }
log_success() { echo -e "${CLR_SUCCESS}[OK]${CLR_RESET} $1"; }
log_warn()    { echo -e "${CLR_WARN}[ADVERTENCIA]${CLR_RESET} $1"; }
log_error()   { echo -e "${CLR_ERROR}[ERROR]${CLR_RESET} $1" >&2; }

# Contadores globales de diagnóstico
CNT_OK=0
CNT_WARN=0
CNT_ERROR=0
CNT_NO_VERIF=0

inc_ok()       { CNT_OK=$((CNT_OK + 1)); }
inc_warn()     { CNT_WARN=$((CNT_WARN + 1)); }
inc_error()    { CNT_ERROR=$((CNT_ERROR + 1)); }
inc_no_verif() { CNT_NO_VERIF=$((CNT_NO_VERIF + 1)); }

mostrar_ayuda() {
    cat <<EOF
Uso: $0 [opciones] [namespace]

Diagnóstico de solo lectura del despliegue en Kubernetes para El Quetzal.
Evalúa el contexto activo, namespace, almacenamiento persistente, configuraciones,
despliegues, réplicas, pods, servicios y endpoints.

Argumentos:
  namespace            Namespace a inspeccionar (predeterminado: proyecto-2-virtual4insanity)

Opciones:
  --context <nombre>   Especifica el contexto Kubernetes a consultar (sin modificar el contexto global)
  --dry-run            Ejecuta exclusivamente la validación estática client-side de manifiestos
  --no-color           Desactiva los códigos de escape de color ANSI
  -h, --help           Muestra esta ayuda y termina con éxito

Seguridad y Ámbito:
  - Estrictamente de SOLO LECTURA. No aplica cambios ni reinicia pods.
  - No altera el contexto global del usuario ('kubectl config use-context' no se invoca).
  - NUNCA imprime contraseñas ni valores de Secrets.
  - Distingue entre el clúster oficial k3s en la VM y clústeres externos (como GKE).
EOF
}

mostrar_resumen() {
    echo ""
    echo "================================================================================"
    echo -e "${CLR_HEADER}${CLR_BOLD} RESUMEN DE DIAGNÓSTICO EJECUTIVO — PROYECTO 2 (KUBERNETES):${CLR_RESET}"
    echo -e " - Comprobaciones satisfactorias [OK]          : ${CLR_SUCCESS}${CNT_OK}${CLR_RESET}"
    echo -e " - Advertencias operativas       [ADVERTENCIA] : ${CLR_WARN}${CNT_WARN}${CLR_RESET}"
    echo -e " - Errores críticos detectados   [ERROR]       : ${CLR_ERROR}${CNT_ERROR}${CLR_RESET}"
    echo -e " - Elementos no verificables     [NO VERIF]    : ${CLR_INFO}${CNT_NO_VERIF}${CLR_RESET}"
    echo "================================================================================"

    local RET_CODE=0
    if [[ "${MODO_SOLO_MANIFESTS}" == true ]]; then
        if [[ ${CNT_ERROR} -eq 0 ]]; then
            log_info "DIAGNÓSTICO: MANIFIESTOS SINTÁCTICAMENTE VÁLIDOS (ESTADO DEL CLÚSTER NO EVALUADO EN MODO DRY-RUN)."
            RET_CODE=0
        else
            log_error "DIAGNÓSTICO: ERRORES DE SINTAXIS DETECTADOS EN MANIFIESTOS (DRY-RUN)."
            RET_CODE=1
        fi
    elif [[ ${CNT_ERROR} -eq 0 && ${CNT_WARN} -eq 0 && ${CNT_NO_VERIF} -eq 0 ]]; then
        if [[ "${ES_CLUSTER_CONFIRMADO:-false}" == true ]]; then
            log_success "DIAGNÓSTICO: CLÚSTER OFICIAL K3S TOTALMENTE OPERATIVO Y SALUDABLE."
            RET_CODE=0
        else
            log_warn "DIAGNÓSTICO: RECURSOS OPERATIVOS PERO ENTORNO NO CONFIRMADO COMO K3S OFICIAL."
            RET_CODE=0
        fi
    elif [[ ${CNT_ERROR} -eq 0 && ${CNT_NO_VERIF} -gt 0 ]]; then
        log_info "DIAGNÓSTICO: ESTADO NO VERIFICADO (CLÚSTER NO OBJETIVO O NO CONECTADO)."
        RET_CODE=0
    elif [[ ${CNT_ERROR} -eq 0 ]]; then
        log_warn "DIAGNÓSTICO: CLÚSTER OPERATIVO CON OBSERVACIONES MENORES."
        RET_CODE=0
    else
        log_error "DIAGNÓSTICO: SE REQUIEREN ACCIONES CORRECTIVAS EN EL CLÚSTER."
        RET_CODE=1
    fi
    echo ""
    return "${RET_CODE}"
}

# 2. Procesamiento de argumentos
NAMESPACE="proyecto-2-virtual4insanity"
KUBE_CONTEXT=""
MODO_SOLO_MANIFESTS=false

ESPERANDO_VALOR_CONTEXT=false
for arg in "$@"; do
    if [[ "${ESPERANDO_VALOR_CONTEXT}" == true ]]; then
        KUBE_CONTEXT="${arg}"
        ESPERANDO_VALOR_CONTEXT=false
        continue
    fi

    case "${arg}" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        --dry-run|--manifests)
            MODO_SOLO_MANIFESTS=true
            ;;
        --no-color)
            CLR_RESET=""
            CLR_HEADER=""
            CLR_INFO=""
            CLR_SUCCESS=""
            CLR_WARN=""
            CLR_ERROR=""
            CLR_BOLD=""
            ;;
        --context=*)
            KUBE_CONTEXT="${arg#*=}"
            ;;
        --context)
            ESPERANDO_VALOR_CONTEXT=true
            ;;
        -*)
            log_error "Opción no reconocida: '${arg}'"
            echo "Uso: $0 [opciones] [namespace] (o -h para ayuda)"
            exit 1
            ;;
        *)
            NAMESPACE="${arg}"
            ;;
    esac
done

if [[ "${ESPERANDO_VALOR_CONTEXT}" == true ]]; then
    log_error "Falta el valor para la opción '--context'."
    exit 1
fi

# Función envoltorio para invocar kubectl con contexto opcional sin modificar el global
k() {
    if [[ -n "${KUBE_CONTEXT}" ]]; then
        kubectl --context="${KUBE_CONTEXT}" "$@"
    else
        kubectl "$@"
    fi
}

echo "================================================================================"
echo -e "${CLR_HEADER}${CLR_BOLD} El Quetzal — Diagnóstico de Orquestación en Kubernetes (k3s)${CLR_RESET}"
echo " Repositorio : ${REPO_ROOT}"
echo " Namespace   : ${NAMESPACE}"
echo " Fecha/Hora  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================================"
echo ""

# 3. Verificación de dependencias locales
log_info "1. Verificando disponibilidad de la herramienta 'kubectl'..."
if ! command -v kubectl >/dev/null 2>&1; then
    log_error "El binario 'kubectl' no está instalado o no se encuentra en el PATH."
    log_error "Instale kubectl o k3s para ejecutar el diagnóstico del clúster."
    exit 1
fi
KUBECTL_VER=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": *"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "instalado")
log_success "kubectl disponible (Versión cliente: ${KUBECTL_VER})"
inc_ok

# 4. Verificación de manifiestos YAML client-side (Siempre ejecutada)
echo ""
log_info "2. Verificando integridad sintáctica de los manifiestos en 'k8s/' (dry-run)..."
K8S_DIR="${REPO_ROOT}/k8s"
if [[ -d "${K8S_DIR}" ]]; then
    if kubectl apply --dry-run=client -f "${K8S_DIR}" >/dev/null 2>&1; then
        TOTAL_YAMLS=$(find "${K8S_DIR}" -maxdepth 1 -name "*.yaml" | wc -l)
        log_success "Todos los manifiestos YAML (${TOTAL_YAMLS} archivos) superaron la validación sintáctica."
        inc_ok
    else
        log_error "Se detectaron errores de sintaxis en los manifiestos YAML de 'k8s/'."
        inc_error
    fi
else
    log_error "No se encontró el directorio de manifiestos: ${K8S_DIR}"
    inc_error
fi

if [[ "${MODO_SOLO_MANIFESTS}" == true ]]; then
    echo ""
    log_info "Modo '--dry-run' solicitado. Se evaluó únicamente la sintaxis client-side de los manifiestos."
    log_info "Omitiendo conexión con el clúster. Las 7 comprobaciones de recursos en vivo quedan como NO VERIFICADAS."
    inc_no_verif  # Namespace
    inc_no_verif  # PVC
    inc_no_verif  # ConfigMaps
    inc_no_verif  # Secret
    inc_no_verif  # Deployments
    inc_no_verif  # Pods
    inc_no_verif  # Services
    mostrar_resumen || exit $?
    exit 0
fi

# 5. Verificación de conectividad y auditoría de contexto
echo ""
log_info "3. Auditando contexto y conectividad con el API Server de Kubernetes..."

if [[ -n "${KUBE_CONTEXT}" ]]; then
    CURRENT_CTX="${KUBE_CONTEXT}"
    log_info "Contexto especificado explícitamente vía argumento: '${CURRENT_CTX}'"
else
    CURRENT_CTX=$(kubectl config current-context 2>/dev/null || echo "desconocido")
    log_info "Contexto activo detectado en kubeconfig: '${CURRENT_CTX}'"
fi

CLUSTER_ACTIVO=false
if k version --request-timeout=4s >/dev/null 2>&1; then
    CLUSTER_ACTIVO=true
fi

if [[ "${CLUSTER_ACTIVO}" == false ]]; then
    log_warn "No se pudo establecer comunicación con el clúster en el contexto '${CURRENT_CTX}'."
    echo ""
    echo "  [NOTA OPERATIVA DEL ROL 5]"
    echo "  La máquina actual no tiene acceso al API Server en el contexto indicado (timeout o máquina apagada)."
    echo "  Esto NO constituye un error del proyecto ni de los manifiestos."
    echo "  Para auditar el estado en tiempo de ejecución, ejecute este script dentro de"
    echo "  la máquina virtual Ubuntu Server oficial donde k3s esté en ejecución."
    echo ""
    # Se registran como pendientes las 7 comprobaciones que requieren clúster activo:
    inc_no_verif  # Namespace
    inc_no_verif  # PVC
    inc_no_verif  # ConfigMaps
    inc_no_verif  # Secret
    inc_no_verif  # Deployments
    inc_no_verif  # Pods
    inc_no_verif  # Services
    mostrar_resumen || exit $?
    exit 0
fi

log_success "Conectividad confirmada con el API Server en el contexto: ${CURRENT_CTX}"
inc_ok

# Evaluación de confirmación del clúster oficial k3s de Proyecto 2
ES_CLUSTER_CONFIRMADO=false
NODE_VERSIONS=$(k get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' 2>/dev/null || echo "")
NODE_NAMES=$(k get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [[ "${NODE_VERSIONS}" =~ k3s ]] || [[ "${NODE_NAMES}" =~ (elquetzal|virtualinsanity|srv-elquetzal) ]] || [[ "${CURRENT_CTX}" =~ (k3s|elquetzal|virtualinsanity|srv-elquetzal) ]]; then
    ES_CLUSTER_CONFIRMADO=true
    log_success "El clúster objetivo ha sido confirmado como entorno k3s de Proyecto 2."
else
    echo ""
    log_warn "================================================================================"
    log_warn "ADVERTENCIA DE CONTEXTO: El clúster activo NO está confirmado como el de Proyecto 2."
    if [[ "${CURRENT_CTX}" =~ gke ]]; then
        log_warn "Se detectó un contexto de Google Kubernetes Engine (GKE) de un laboratorio anterior."
    elif [[ "${CURRENT_CTX}" =~ docker-desktop ]]; then
        log_warn "Se detectó el contexto de Docker Desktop."
    else
        log_warn "El contexto '${CURRENT_CTX}' no coincide con el clúster k3s en la VM Ubuntu Server."
    fi
    log_info "El clúster oficial debe ejecutarse bajo k3s en la máquina virtual Ubuntu Server."
    log_info "Si dispone de otro contexto, ejecute: $0 --context <nombre_contexto>"
    log_warn "================================================================================"
    echo ""
fi

# 6. Verificación del Namespace
log_info "4. Verificando existencia del Namespace '${NAMESPACE}'..."
if k get ns "${NAMESPACE}" >/dev/null 2>&1; then
    NS_STATUS=$(k get ns "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Active")
    log_success "Namespace '${NAMESPACE}' presente y en estado '${NS_STATUS}'."
    inc_ok
else
    if [[ "${ES_CLUSTER_CONFIRMADO}" == false ]]; then
        log_warn "El namespace '${NAMESPACE}' no existe en este contexto externo ('${CURRENT_CTX}')."
        echo ""
        echo "  [DIAGNÓSTICO NO CONCLUYENTE — CLÚSTER NO CONFIRMADO]"
        echo "  El contexto actual ('${CURRENT_CTX}') corresponde a un entorno externo de laboratorio"
        echo "  y no a la máquina virtual oficial Ubuntu Server donde debe residir k3s."
        echo "  La ausencia del namespace en este clúster ajeno NO indica un fallo en el despliegue oficial."
        echo "  Para verificar el despliegue oficial:"
        echo "    1. Ejecute este script en la VM Ubuntu Server con k3s."
        echo "    2. O especifique el contexto k3s: $0 --context <contexto-k3s>"
        echo ""
        # Se contabiliza como NO VERIFICADO en lugar de ERROR del proyecto
        inc_no_verif  # Namespace
        inc_no_verif  # PVC
        inc_no_verif  # ConfigMaps
        inc_no_verif  # Secret
        inc_no_verif  # Deployments
        inc_no_verif  # Pods
        inc_no_verif  # Services
        mostrar_resumen || exit $?
        exit 0
    else
        log_error "El namespace '${NAMESPACE}' NO existe en el clúster k3s oficial."
        log_info "Debe aplicarse con: kubectl apply -f k8s/namespace.yaml"
        inc_error
        inc_no_verif
        inc_no_verif
        inc_no_verif
        inc_no_verif
        inc_no_verif
        inc_no_verif
        mostrar_resumen || exit $?
        exit 1
    fi
fi

# 7. Verificación de PersistentVolumeClaim (PVC) de PostgreSQL
echo ""
log_info "5. Verificando PersistentVolumeClaim de Base de Datos ('elquetzal-pgdata')..."
if k get pvc -n "${NAMESPACE}" elquetzal-pgdata >/dev/null 2>&1; then
    PVC_PHASE=$(k get pvc -n "${NAMESPACE}" elquetzal-pgdata -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    PVC_SC=$(k get pvc -n "${NAMESPACE}" elquetzal-pgdata -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "default")
    PVC_CAP=$(k get pvc -n "${NAMESPACE}" elquetzal-pgdata -o jsonpath='{.status.capacity.storage}' 2>/dev/null || echo "solicitado 2Gi")
    if [[ "${PVC_PHASE}" == "Bound" ]]; then
        log_success "PVC 'elquetzal-pgdata' enlazado (Phase: Bound, StorageClass: ${PVC_SC}, Capacidad: ${PVC_CAP})."
        inc_ok
    else
        log_warn "PVC 'elquetzal-pgdata' existe pero su estado es '${PVC_PHASE}' (StorageClass: ${PVC_SC})."
        inc_warn
    fi
else
    log_error "PVC 'elquetzal-pgdata' NO encontrado en el namespace '${NAMESPACE}'."
    inc_error
fi

# 8. Verificación de ConfigMaps
echo ""
log_info "6. Verificando ConfigMaps requeridos..."
CONFIGMAPS_REQUERIDOS=("elquetzal-db-config" "elquetzal-db-init" "elquetzal-backend-config")
for cm in "${CONFIGMAPS_REQUERIDOS[@]}"; do
    if k get configmap -n "${NAMESPACE}" "${cm}" >/dev/null 2>&1; then
        NUM_KEYS=$(k get configmap -n "${NAMESPACE}" "${cm}" -o jsonpath='{.data}' 2>/dev/null | grep -o ':[^,]*' | wc -l || echo "1+")
        log_success "ConfigMap '${cm}' presente (claves registradas: ${NUM_KEYS})."
        inc_ok
    else
        log_error "ConfigMap '${cm}' NO encontrado en el namespace '${NAMESPACE}'."
        inc_error
    fi
done

# 9. Verificación de Secret de Base de Datos (SIN EXPONER VALORES)
echo ""
log_info "7. Verificando Secret de Base de Datos ('elquetzal-db-secret')..."
if k get secret -n "${NAMESPACE}" elquetzal-db-secret >/dev/null 2>&1; then
    # Usamos 'describe' para validar exclusivamente los nombres de las claves en la sección Data
    # NUNCA se extraen ni imprimen valores base64 ni texto plano
    DESCRIBE_SEC=$(k describe secret -n "${NAMESPACE}" elquetzal-db-secret 2>/dev/null || true)
    CLAVES_FALTANTES=()
    CLAVES_ESPERADAS=("POSTGRES_PASSWORD" "CATALOGO_DB_PASSWORD" "INVENTARIO_DB_PASSWORD" "CLIENTES_DB_PASSWORD" "PEDIDOS_DB_PASSWORD" "REPORTES_DB_PASSWORD")
    for k_name in "${CLAVES_ESPERADAS[@]}"; do
        if ! echo "${DESCRIBE_SEC}" | grep -q "${k_name}:"; then
            CLAVES_FALTANTES+=("${k_name}")
        fi
    done

    if [[ ${#CLAVES_FALTANTES[@]} -eq 0 ]]; then
        log_success "Secret 'elquetzal-db-secret' presente con las 6 claves requeridas (contenido estrictamente protegido)."
        inc_ok
    else
        log_warn "Secret 'elquetzal-db-secret' presente pero carece de las claves: ${CLAVES_FALTANTES[*]}."
        inc_warn
    fi
else
    log_error "Secret 'elquetzal-db-secret' NO encontrado en el namespace '${NAMESPACE}'."
    log_info "Debe generarse en la VM antes del despliegue (ver k8s/ejemplos/db-secret.example.yaml)."
    inc_error
fi

# 10. Verificación de Deployments y Comparación de Réplicas
echo ""
log_info "8. Verificando Deployments y Réplicas (Deseadas vs Disponibles)..."
DEPLOYMENTS_ESPERADOS=(
    "gateway|virtual4insanity/elquetzal-gateway:2.0"
    "elquetzal-db|postgres:16-alpine"
    "api-catalogo|virtual4insanity/elquetzal-catalogo:2.0"
    "api-inventario|virtual4insanity/elquetzal-inventario:2.0"
    "api-clientes|virtual4insanity/elquetzal-clientes:1.0"
    "api-pedidos|virtual4insanity/elquetzal-pedidos:2.1"
    "api-reportes|virtual4insanity/elquetzal-reportes:1.0"
    "elquetzal-frontend|virtual4insanity/elquetzal-frontend:2.2"
)

printf "%-20s | %-10s | %-12s | %-42s\n" "DEPLOYMENT" "RÉPLICAS" "ESTADO" "IMAGEN UTILIZADA"
printf "%-20s-+-%-10s-+-%-12s-+-%-42s\n" "--------------------" "----------" "------------" "------------------------------------------"

for item in "${DEPLOYMENTS_ESPERADOS[@]}"; do
    IFS="|" read -r dep_name dep_img <<< "${item}"
    if k get deployment -n "${NAMESPACE}" "${dep_name}" >/dev/null 2>&1; then
        DESIRED=$(k get deployment -n "${NAMESPACE}" "${dep_name}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        READY=$(k get deployment -n "${NAMESPACE}" "${dep_name}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        CURRENT_IMG=$(k get deployment -n "${NAMESPACE}" "${dep_name}" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "desconocida")

        if [[ "${DESIRED}" == "${READY}" && "${READY}" -gt 0 ]]; then
            if [[ "${CURRENT_IMG}" == "${dep_img}" ]]; then
                DEP_STATUS="OK"
                inc_ok
            else
                DEP_STATUS="Tag dispar"
                log_warn "Deployment '${dep_name}': Imagen en ejecución (${CURRENT_IMG}) difiere de la esperada (${dep_img})."
                inc_warn
            fi
        elif [[ "${READY}" -eq 0 ]]; then
            DEP_STATUS="Sin réplicas"
            inc_error
        else
            DEP_STATUS="Parcial"
            inc_warn
        fi

        printf "%-20s | %-10s | %-12s | %-42s\n" "${dep_name}" "${READY}/${DESIRED}" "${DEP_STATUS}" "${CURRENT_IMG}"
    else
        printf "%-20s | %-10s | %-12s | %-42s\n" "${dep_name}" "0/0" "No existe" "Ausente"
        inc_error
    fi
done

# 11. Detección de Errores en Pods
echo ""
log_info "9. Inspeccionando estado y salud de los Pods..."
PODS_TOTALES=$(k get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo "0")

if [[ "${PODS_TOTALES}" -gt 0 ]]; then
    PODS_CON_PROBLEMAS=0
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then continue; fi
        P_NAME=$(echo "${line}" | awk '{print $1}')
        P_READY=$(echo "${line}" | awk '{print $2}')
        P_STATUS=$(echo "${line}" | awk '{print $3}')
        P_RESTARTS=$(echo "${line}" | awk '{print $4}')

        if [[ "${P_STATUS}" == "Running" || "${P_STATUS}" == "Completed" ]]; then
            log_success "Pod: ${P_NAME} | Estado: ${P_STATUS} | Contenedores: ${P_READY} | Reinicios: ${P_RESTARTS}"
            inc_ok
        else
            log_error "Pod con problema: ${P_NAME} | Estado: ${P_STATUS} | Contenedores: ${P_READY} | Reinicios: ${P_RESTARTS}"
            PODS_CON_PROBLEMAS=$((PODS_CON_PROBLEMAS + 1))
            inc_error
        fi
    done < <(k get pods -n "${NAMESPACE}" --no-headers 2>/dev/null)

    if [[ ${PODS_CON_PROBLEMAS} -eq 0 ]]; then
        log_success "Todos los pods (${PODS_TOTALES}) están en ejecución normal."
    else
        log_warn "Se detectaron ${PODS_CON_PROBLEMAS} pod(s) con estados anómalos."
    fi
else
    log_warn "No se encontraron pods activos en el namespace '${NAMESPACE}'."
    inc_warn
fi

# 12. Verificación de Services y Endpoints
echo ""
log_info "10. Verificando Services y Endpoints de red..."
SERVICES_ESPERADOS=(
    "gateway|NodePort|30080"
    "db|ClusterIP|5432"
    "api-catalogo|ClusterIP|5000"
    "api-inventario|ClusterIP|5000"
    "api-clientes|ClusterIP|5000"
    "api-pedidos|ClusterIP|5000"
    "api-reportes|ClusterIP|5000"
    "frontend|ClusterIP|80"
)

printf "%-18s | %-10s | %-12s | %-15s\n" "SERVICE" "TIPO" "PUERTO/NODE" "ENDPOINTS"
printf "%-18s-+-%-10s-+-%-12s-+-%-15s\n" "------------------" "----------" "------------" "---------------"

for item in "${SERVICES_ESPERADOS[@]}"; do
    IFS="|" read -r s_name s_type s_port <<< "${item}"
    if k get svc -n "${NAMESPACE}" "${s_name}" >/dev/null 2>&1; then
        ACTUAL_TYPE=$(k get svc -n "${NAMESPACE}" "${s_name}" -o jsonpath='{.spec.type}' 2>/dev/null || echo "ClusterIP")
        ACTUAL_EP=$(k get endpoints -n "${NAMESPACE}" "${s_name}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

        EP_STATUS="Sin endpoints"
        if [[ -n "${ACTUAL_EP}" ]]; then
            EP_COUNT=$(echo "${ACTUAL_EP}" | wc -w)
            EP_STATUS="${EP_COUNT} activo(s)"
            inc_ok
        else
            inc_warn
        fi

        printf "%-18s | %-10s | %-12s | %-15s\n" "${s_name}" "${ACTUAL_TYPE}" "${s_port}" "${EP_STATUS}"
    else
        printf "%-18s | %-10s | %-12s | %-15s\n" "${s_name}" "Ausente" "N/A" "No existe"
        inc_error
    fi
done

# 13. Resumen Ejecutivo Final
mostrar_resumen || exit $?
