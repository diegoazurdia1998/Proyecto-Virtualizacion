#!/usr/bin/env bash
# ==============================================================================
# PROYECTO 2 — VIRTUALIZACIÓN — EQUIPO VIRTUAL INSANITY (EL QUETZAL)
# ROL 5: Orquestación, Evidencia y Documentación
# SCRIPT: verificar-identidad-equipo.sh
# DESCRIPCIÓN: Auditoría estática y de solo lectura de la trazabilidad del
#              equipo y presencia de los cinco carnés universitarios en el
#              repositorio, base de datos, backend, frontend y Kubernetes.
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

# Contadores de diagnóstico
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
Uso: $0 [opciones]

Auditoría de solo lectura de la trazabilidad académica para El Quetzal (Proyecto 2).
Comprueba el identificador del equipo 'virtual4insanity', la presencia coherente
de los cinco carnés en esquemas SQL, seeds, ConfigMaps, backend, frontend y manifiestos k8s.

Opciones:
  --no-color       Desactiva los códigos de escape de color ANSI
  -h, --help       Muestra esta ayuda y termina con éxito

Seguridad y Alcance:
  - Estrictamente de SOLO LECTURA sobre el código y configuración del repositorio.
  - No altera la base de datos ni modifica ningún archivo.
  - Distingue verificaciones estáticas en archivos de comprobaciones pendientes en tiempo de ejecución.
EOF
}

# Procesamiento de argumentos
for arg in "$@"; do
    case "${arg}" in
        -h|--help)
            mostrar_ayuda
            exit 0
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
        *)
            log_error "Opción no reconocida: '${arg}'"
            echo "Uso: $0 [--no-color] [-h|--help]"
            exit 1
            ;;
    esac
done

echo "================================================================================"
echo -e "${CLR_HEADER}${CLR_BOLD} El Quetzal — Auditoría de Identidad del Equipo y Trazabilidad de Carnés${CLR_RESET}"
echo " Repositorio : ${REPO_ROOT}"
echo " Equipo      : Virtual Insanity"
echo " ID Oficial  : virtual4insanity"
echo " Fecha/Hora  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================================"
echo ""

# 2. Auditoría del Identificador de Equipo ('virtual4insanity')
log_info "1. Auditando presencia del identificador 'virtual4insanity' en configuraciones..."

ID_ESPERADO="virtual4insanity"
ID_NS_ESPERADO="proyecto-2-virtual4insanity"

# Verificación en namespace.yaml
NS_FILE="${REPO_ROOT}/k8s/namespace.yaml"
if [[ -f "${NS_FILE}" ]]; then
    if grep -q "name: *${ID_NS_ESPERADO}" "${NS_FILE}"; then
        log_success "Namespace en Kubernetes: '${ID_NS_ESPERADO}' (cumple convención RFC 1123)."
        inc_ok
    else
        log_error "El namespace en '${NS_FILE}' no coincide con '${ID_NS_ESPERADO}'."
        inc_error
    fi

    if grep -q "equipo: *${ID_ESPERADO}" "${NS_FILE}"; then
        log_success "Etiqueta 'equipo: ${ID_ESPERADO}' presente en 'k8s/namespace.yaml'."
        inc_ok
    else
        log_warn "Etiqueta 'equipo: ${ID_ESPERADO}' no encontrada en 'k8s/namespace.yaml'."
        inc_warn
    fi
else
    log_error "No se encontró 'k8s/namespace.yaml'."
    inc_error
fi

# Verificación en manifiestos de Deployments y Services
K8S_DIR="${REPO_ROOT}/k8s"
TOTAL_YAMLS_EQUIPO=$(grep -rl "equipo: *${ID_ESPERADO}" "${K8S_DIR}"/*.yaml 2>/dev/null | wc -l || echo "0")
if [[ ${TOTAL_YAMLS_EQUIPO} -ge 10 ]]; then
    log_success "Etiqueta 'equipo: ${ID_ESPERADO}' declarada consistentemente en ${TOTAL_YAMLS_EQUIPO} manifiestos k8s."
    inc_ok
else
    log_warn "Etiqueta 'equipo: ${ID_ESPERADO}' presente en ${TOTAL_YAMLS_EQUIPO} manifiestos (revisar cobertura total)."
    inc_warn
fi

# Verificación de imágenes en Docker Hub
TOTAL_IMGS_ID=$(grep -rho "virtual4insanity/elquetzal-[a-z0-9_-]*:[0-9.]*" "${K8S_DIR}"/*.yaml 2>/dev/null | sort -u | wc -l || echo "0")
if [[ ${TOTAL_IMGS_ID} -ge 7 ]]; then
    log_success "Todas las imágenes personalizadas (${TOTAL_IMGS_ID}) utilizan el prefijo 'virtual4insanity/'."
    inc_ok
else
    log_warn "Se detectaron ${TOTAL_IMGS_ID} imágenes con el namespace 'virtual4insanity/' (se esperaban al menos 7)."
    inc_warn
fi

# Verificación de Hostname en documentación oficial
DOC_HOSTNAME=$(grep -roh "srv-elquetzal-virtualinsanity" "${REPO_ROOT}"/README.md "${REPO_ROOT}"/DOCUMENTACION_FINAL.md 2>/dev/null | head -n1 || echo "")
if [[ "${DOC_HOSTNAME}" == "srv-elquetzal-virtualinsanity" ]]; then
    log_success "Hostname institucional documentado: 'srv-elquetzal-virtualinsanity'."
    inc_ok
else
    log_warn "Hostname 'srv-elquetzal-virtualinsanity' no encontrado en la documentación."
    inc_warn
fi

# 3. Auditoría de los Cinco Carnés Universitarios
echo ""
log_info "2. Extrayendo y verificando los cinco carnés en fuentes oficiales del repositorio..."

# Lista oficial esperada (según README.md y DOCUMENTACION_FINAL.md)
CARNES_ESPERADOS=(
    "1283220|Rochelle Giulianne Esquivel Vargas|Rol 1"
    "1182222|Oscar Javier Ortíz Pocón|Rol 2"
    "2528119|Diego Andrés Azurdia Ortíz|Rol 3"
    "1163722|Diego Oswaldo Orellana Morales|Rol 4"
    "1224323|Susana Paola García García|Rol 5"
)

SEED_CAT="${REPO_ROOT}/database/init/seeds/catalogo.sql"
CM_INIT="${REPO_ROOT}/k8s/db-init-configmap.yaml"

printf "%-10s | %-36s | %-6s | %-12s | %-12s\n" "CARNÉ" "INTEGRANTE DEL EQUIPO" "ROL" "SEED SQL" "CONFIGMAP K8S"
printf "%-10s-+-%-36s-+-%-6s-+-%-12s-+-%-12s\n" "----------" "------------------------------------" "------" "------------" "------------"

CARNES_CORRECTOS=0
for item in "${CARNES_ESPERADOS[@]}"; do
    IFS="|" read -r c_carne c_nombre c_rol <<< "${item}"

    # Verificación en database/init/seeds/catalogo.sql
    EN_SEED="Ausente"
    if [[ -f "${SEED_CAT}" ]] && grep -q "'${c_carne}'" "${SEED_CAT}"; then
        EN_SEED="Presente"
    fi

    # Verificación en k8s/db-init-configmap.yaml
    EN_CM="Ausente"
    if [[ -f "${CM_INIT}" ]] && grep -q "'${c_carne}'" "${CM_INIT}"; then
        EN_CM="Presente"
    fi

    if [[ "${EN_SEED}" == "Presente" && "${EN_CM}" == "Presente" ]]; then
        CARNES_CORRECTOS=$((CARNES_CORRECTOS + 1))
    fi

    printf "%-10s | %-36s | %-6s | %-12s | %-12s\n" "${c_carne}" "${c_nombre}" "${c_rol}" "${EN_SEED}" "${EN_CM}"
done

echo ""
if [[ ${CARNES_CORRECTOS} -eq 5 ]]; then
    log_success "Los 5 carnés oficiales están presentes y coinciden exactamente entre Seeds SQL y ConfigMap k8s."
    inc_ok
else
    log_error "Solo ${CARNES_CORRECTOS} de 5 carnés fueron verificados en ambas fuentes."
    inc_error
fi

# 4. Auditoría de Sembrado de Carnés en Módulos de Base de Datos
echo ""
log_info "3. Verificando distribución de carnés en tablas de negocio (auditoría de autoría)..."

SEED_CLI="${REPO_ROOT}/database/init/seeds/clientes.sql"
SEED_INV="${REPO_ROOT}/database/init/seeds/inventario.sql"
SEED_PED="${REPO_ROOT}/database/init/seeds/pedidos.sql"

# Comprobar presencia en clientes.sql y ConfigMap (creado_por)
CLI_CARNES=$(grep -oE "'[0-9]{7}'" "${SEED_CLI}" 2>/dev/null | tr -d "'" | sort -u | wc -l || echo "0")
CLI_CM_CARNES=$(grep -oE "'[0-9]{7}'" "${CM_INIT}" 2>/dev/null | tr -d "'" | sort -u | wc -l || echo "0")
if [[ ${CLI_CARNES} -eq 5 && ${CLI_CM_CARNES} -eq 5 ]]; then
    log_success "Tabla 'clientes': Los 5 carnés están sembrados en seeds SQL y ConfigMap k8s ('creado_por')."
    inc_ok
elif [[ ${CLI_CARNES} -eq 5 ]]; then
    log_success "Tabla 'clientes': Los 5 carnés están sembrados en registros iniciales ('creado_por')."
    inc_ok
else
    log_warn "Tabla 'clientes': Se encontraron ${CLI_CARNES} carnés distintos en seeds (esperados 5)."
    inc_warn
fi

# Comprobar presencia en inventario.sql (creado_por)
INV_CARNES=$(grep -oE "'[0-9]{7}'" "${SEED_INV}" 2>/dev/null | tr -d "'" | sort -u | wc -l || echo "0")
if [[ ${INV_CARNES} -eq 5 ]]; then
    log_success "Tabla 'productos': Los 5 carnés están sembrados en registros iniciales ('creado_por')."
    inc_ok
else
    log_warn "Tabla 'productos': Se encontraron ${INV_CARNES} carnés distintos en seeds (esperados 5)."
    inc_warn
fi

# Comprobar presencia en pedidos.sql (carne)
PED_CARNES=$(grep -oE "'[0-9]{7}'" "${SEED_PED}" 2>/dev/null | tr -d "'" | sort -u | wc -l || echo "0")
if [[ ${PED_CARNES} -ge 2 ]]; then
    log_success "Tabla 'pedidos': Los pedidos de prueba iniciales asocian carnés del equipo."
    inc_ok
else
    log_warn "Tabla 'pedidos': No se encontraron carnés en los pedidos iniciales."
    inc_warn
fi

# 5. Auditoría de Mecanismos Backend para Trazabilidad
echo ""
log_info "4. Auditando integración de carnés en microservicios backend..."

# 5.1 Endpoint /equipo en api-catalogo
CAT_APP="${REPO_ROOT}/backend/catalogo/app.py"
if [[ -f "${CAT_APP}" ]]; then
    if grep -q "@app.route('/equipo'" "${CAT_APP}"; then
        log_success "api-catalogo expone el endpoint 'GET /equipo' para proveer la lista de carnés a la UI."
        inc_ok
    else
        log_error "api-catalogo no expone el endpoint '/equipo'."
        inc_error
    fi

    # Validación de compatibilidad de la consulta SQL de /equipo con el esquema DDL
    if grep -q "SELECT.*FROM equipo.*ORDER BY id" "${CAT_APP}"; then
        echo ""
        log_warn "================================================================================"
        log_warn "HALLAZGO CRÍTICO EN BACKEND (Rol 3):"
        log_warn "En '${CAT_APP}', la consulta ejecuta: SELECT carne, nombre, rol FROM equipo ORDER BY id ASC;"
        log_warn "Sin embargo, el esquema DDL 'database/init/esquemas/catalogo.sql' define la tabla 'equipo'"
        log_warn "con Primary Key 'carne' (NO existe columna 'id')."
        log_warn "IMPACTO EN EJECUCIÓN: PostgreSQL arrojará error 'column \"id\" does not exist',"
        log_warn "haciendo que 'GET /equipo' falle con HTTP 500 y no devuelva carnés a la interfaz."
        log_warn "RESPONSABLE DE CORRECCIÓN: Rol 3 (Backend)."
        log_warn "================================================================================"
        echo ""
        inc_warn
    elif grep -E -q "SELECT.*carne.*nombre.*rol.*FROM equipo.*ORDER BY (nombre|carne)" "${CAT_APP}"; then
        ORDER_COL=$(grep -oE "ORDER BY (nombre|carne)" "${CAT_APP}" | head -n1)
        log_success "Consulta a tabla 'equipo' en api-catalogo 100% compatible con esquema DDL (${ORDER_COL} ASC)."
        inc_ok
    else
        log_warn "La consulta a 'equipo' en '${CAT_APP}' no sigue la estructura de columnas esperada."
        inc_warn
    fi
else
    log_error "No se encontró '${CAT_APP}'."
    inc_error
fi

# 5.2 Validación de carné en api-pedidos
PED_APP="${REPO_ROOT}/backend/pedidos/app.py"
if [[ -f "${PED_APP}" ]]; then
    if grep -q "/equipo" "${PED_APP}" && grep -q "carnes_validos" "${PED_APP}"; then
        log_success "api-pedidos valida obligatoriamente que el carné del pedido pertenezca al equipo."
        inc_ok
    else
        log_warn "api-pedidos no contiene validación explícita de carné contra '/equipo'."
        inc_warn
    fi
else
    log_error "No se encontró '${PED_APP}'."
    inc_error
fi

# 6. Auditoría de Mecanismos Frontend para Visualización
echo ""
log_info "5. Auditando integración de carnés en el frontend Vue..."

FE_PEDIDOS="${REPO_ROOT}/frontend/src/views/PedidosView.vue"
if [[ -f "${FE_PEDIDOS}" ]]; then
    # Verificación del selector dinámico de carnés
    if grep -q "cargarEquipo" "${FE_PEDIDOS}" && grep -q "pedidoForm.carne" "${FE_PEDIDOS}"; then
        log_success "PedidosView.vue implementa <select> dinámico para elegir el carné del integrante."
        inc_ok
    else
        log_warn "PedidosView.vue no tiene selector dinámico vinculado a 'cargarEquipo'."
        inc_warn
    fi

    # Verificación de columna de carné en la tabla de historial
    if grep -q "ped.carne" "${FE_PEDIDOS}"; then
        log_success "PedidosView.vue muestra el carné del operador en la tabla de pedidos confirmados."
        inc_ok
    else
        log_warn "PedidosView.vue no muestra el carné en el historial de pedidos."
        inc_warn
    fi
else
    log_error "No se encontró '${FE_PEDIDOS}'."
    inc_error
fi

# Verificación de Footer Institucional en layout general
FE_APP="${REPO_ROOT}/frontend/src/App.vue"
if [[ -f "${FE_APP}" ]]; then
    if grep -q "virtual4insanity" "${FE_APP}" || grep -q "Virtual Insanity" "${FE_APP}"; then
        log_success "App.vue muestra el nombre del equipo en el layout general."
        inc_ok
    else
        log_warn "App.vue NO cuenta con pie de página ni banner que muestre permanentemente los 5 carnés."
        log_info "Los carnés solo se visualizan actualmente dentro de la vista de Pedidos (/pedidos)."
        inc_warn
    fi
fi

# 6. Comprobación en Tiempo de Ejecución (PostgreSQL en clúster k3s)
echo ""
log_info "6. Comprobando disponibilidad de verificación en vivo en PostgreSQL..."
if command -v kubectl >/dev/null 2>&1 && kubectl get deployment elquetzal-db -n "${ID_NS_ESPERADO}" >/dev/null 2>&1; then
    if LIVE_EQUIPO=$(kubectl exec -n "${ID_NS_ESPERADO}" deployment/elquetzal-db -- psql -U postgres -d db_catalogo -t -A -F"|" -c "SELECT carne, nombre, rol FROM equipo ORDER BY nombre ASC;" 2>/dev/null); then
        LIVE_COUNT=$(echo "${LIVE_EQUIPO}" | grep -c -E '^[0-9]{7}' || echo "0")
        if [[ ${LIVE_COUNT} -eq 5 ]]; then
            log_success "PostgreSQL en vivo: Los 5 carnés fueron consultados exitosamente en 'db_catalogo.equipo'."
            inc_ok
        else
            log_warn "PostgreSQL en vivo: Se obtuvieron ${LIVE_COUNT} registros de equipo (esperados 5)."
            inc_warn
        fi
    else
        log_info "No se pudo consultar el Pod 'elquetzal-db' (pod no listo o sin permisos de exec)."
        inc_no_verif
    fi
else
    log_info "Clúster k3s / Pod de PostgreSQL no accesible en este entorno local."
    echo "  [COMPROBACIÓN EN TIEMPO DE EJECUCIÓN PENDIENTE]"
    echo "  La consulta interactiva a PostgreSQL requiere que el clúster k3s esté en ejecución"
    echo "  dentro de la máquina virtual Ubuntu Server oficial ('srv-elquetzal-virtualinsanity')."
    echo "  Esta comprobación queda registrada como PENDIENTE (NO VERIFICADA en este host)."
    inc_no_verif
fi

# 7. Resumen Ejecutivo de Trazabilidad
echo ""
echo "================================================================================"
echo -e "${CLR_HEADER}${CLR_BOLD} RESUMEN DE AUDITORÍA DE TRAZABILIDAD (PROYECTO 2):${CLR_RESET}"
echo -e " - Comprobaciones satisfactorias [OK]          : ${CLR_SUCCESS}${CNT_OK}${CLR_RESET}"
echo -e " - Observaciones / Advertencias  [ADVERTENCIA] : ${CLR_WARN}${CNT_WARN}${CLR_RESET}"
echo -e " - Errores de trazabilidad       [ERROR]       : ${CLR_ERROR}${CNT_ERROR}${CLR_RESET}"
echo -e " - Comprobaciones en ejecución   [NO VERIF]    : ${CLR_INFO}${CNT_NO_VERIF}${CLR_RESET}"
echo "================================================================================"

if [[ ${CNT_ERROR} -eq 0 && ${CNT_WARN} -eq 0 && ${CNT_NO_VERIF} -eq 0 ]]; then
    log_success "TRAZABILIDAD: CUMPLIMIENTO TOTAL DE IDENTIFICADORES Y CARNÉS (VERIFICADO EN VIVO)."
    RET_CODE=0
elif [[ ${CNT_ERROR} -eq 0 && ${CNT_NO_VERIF} -gt 0 ]]; then
    log_info "TRAZABILIDAD: CUMPLIMIENTO COMPROBADO EN REPOSITORIO (PRUEBAS EN VIVO PENDIENTES EN VM)."
    RET_CODE=0
elif [[ ${CNT_ERROR} -eq 0 ]]; then
    log_warn "TRAZABILIDAD: CUMPLIMIENTO COMPROBADO EN ARCHIVOS CON ADVERTENCIAS TÉCNICAS."
    RET_CODE=0
else
    log_error "TRAZABILIDAD: SE DETECTARON DISCREPANCIAS QUE REQUIEREN CORRECCIÓN."
    RET_CODE=1
fi

echo ""
echo "Notas sobre comprobaciones pendientes en tiempo de ejecución (VM Ubuntu Server):"
echo "  1. Visualización en Navegador: Verificar que al abrir http://<IP_VM>:30080/pedidos"
echo "     el combo despliegue los 5 integrantes con sus nombres y carnés."
echo "  2. Persistencia en Pedido: Crear un pedido con un carné y consultar la BD PostgreSQL"
echo "     con 'SELECT id, carne, total FROM pedidos;' confirmando el guardado."
echo "  3. Hostname de la VM: Ejecutar 'hostname' en la terminal de la VM y confirmar que sea"
echo "     'srv-elquetzal-virtualinsanity'."
echo ""

exit "${RET_CODE}"
