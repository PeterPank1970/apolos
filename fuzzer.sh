#!/bin/bash

# Script de Fuzzing con barra de progreso, wordlist externa y análisis de resultados
# Uso: ./fuzzer.sh [-w wordlist.txt] [-o output_prefix]

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración
BASE_URL="172.17.0.2"
DEFAULT_WORDLIST="wordlist_params.txt"
DEFAULT_PREFIX="jwt"
DELAY=0.2
TIMEOUT=3
TOTAL_TESTS=0
CURRENT_TEST=0

# Archivos objetivo
declare -a TARGET_FILES=(
    "/vendor/composer/ClassLoader.php"
    "/vendor/composer/InstalledVersions.php"
    "/vendor/composer/autoload_classmap.php"
    "/vendor/composer/autoload_namespaces.php"
    "/vendor/composer/autoload_psr4.php"
    "/vendor/composer/autoload_real.php"
    "/vendor/composer/autoload_static.php"
    "/vendor/composer/installed.json"
    "/vendor/composer/installed.php"
    "/vendor/composer/platform_check.php"
    "/vendor/firebase/php-jwt/src/BeforeValidException.php"
    "/vendor/firebase/php-jwt/src/CachedKeySet.php"
    "/vendor/firebase/php-jwt/src/ExpiredException.php"
    "/vendor/firebase/php-jwt/src/JWK.php"
    "/vendor/firebase/php-jwt/src/JWT.php"
    "/vendor/firebase/php-jwt/src/JWTExceptionWithPayloadInterface.php"
    "/vendor/firebase/php-jwt/src/Key.php"
    "/vendor/firebase/php-jwt/src/SignatureInvalidException.php"
)

# Mostrar ayuda
show_help() {
  echo -e "${YELLOW}Uso:${NC} $0 [-w wordlist.txt] [-o output_prefix]"
  echo -e "${YELLOW}Opciones:${NC}"
  echo -e "  -w <wordlist>\tWordlist personalizada (default: ${DEFAULT_WORDLIST})"
  echo -e "  -o <prefix>\tPrefijo para archivos de salida (default: ${DEFAULT_PREFIX})"
  exit 0
}

# Procesar parámetros
while getopts "w:o:h" opt; do
  case $opt in
    w) WORDLIST="$OPTARG" ;;
    o) PREFIX="$OPTARG" ;;
    h) show_help ;;
    *) echo -e "${RED}Opción inválida${NC}"; show_help ;;
  esac
done

# Establecer valores por defecto
WORDLIST=${WORDLIST:-$DEFAULT_WORDLIST}
PREFIX=${PREFIX:-$DEFAULT_PREFIX}

# Archivos de salida
RESULTS_FILE="${PREFIX}_results.txt"
CONTENT_FILE="${PREFIX}_results_content.txt"
ANALYSIS_FILE="${PREFIX}_analysis.txt"

# Verificar wordlist
if [ ! -f "$WORDLIST" ]; then
  echo -e "${RED}Error: No se encontró la wordlist ${WORDLIST}${NC}"
  exit 1
fi

# Función para mostrar barra de progreso
show_progress() {
  local width=50
  local percent=$(( CURRENT_TEST * 100 / TOTAL_TESTS ))
  local filled=$(( width * percent / 100 ))
  
  printf "\r["
  printf "%${filled}s" | tr ' ' '#'
  printf "%$((width-filled))s" | tr ' ' '-'
  printf "] %3d%% (%d/%d)" $percent $CURRENT_TEST $TOTAL_TESTS
}

# Función para analizar resultados
analyze_results() {
  echo -e "\n${CYAN}[*] Analizando resultados...${NC}"
  
  # Crear archivo de análisis
  echo -e "Análisis de resultados - $(date)\n" > "$ANALYSIS_FILE"
  echo -e "=== RESUMEN ESTADÍSTICO ===" >> "$ANALYSIS_FILE"
  
  # Contar hallazgos totales
  total_finds=$(grep -c "^\[+\]" "$RESULTS_FILE" 2>/dev/null || echo 0)
  echo -e "Hallazgos totales: ${total_finds}" >> "$ANALYSIS_FILE"
  
  # Contar por código de estado HTTP
  echo -e "\n=== CÓDIGOS DE ESTADO ===" >> "$ANALYSIS_FILE"
  grep -o "(HTTP [0-9][0-9][0-9])" "$RESULTS_FILE" | sort | uniq -c | sort -nr >> "$ANALYSIS_FILE"
  
  # Parámetros más frecuentes
  echo -e "\n=== PARÁMETROS MÁS FRECUENTES ===" >> "$ANALYSIS_FILE"
  grep -o "?[^= ]*" "$RESULTS_FILE" | cut -d? -f2 | cut -d= -f1 | sort | uniq -c | sort -nr | head -10 >> "$ANALYSIS_FILE"
  
  # Archivos más vulnerables
  echo -e "\n=== ARCHIVOS MÁS VULNERABLES ===" >> "$ANALYSIS_FILE"
  grep -o "http://[^?]*" "$RESULTS_FILE" | sort | uniq -c | sort -nr | head -5 >> "$ANALYSIS_FILE"
  
  # Mostrar resumen en pantalla
  echo -e "${CYAN}[+] Análisis completado:${NC}"
  echo -e " - Hallazgos totales: ${total_finds}"
  echo -e " - Archivo de resultados: ${RESULTS_FILE}"
  echo -e " - Contenidos de respuestas: ${CONTENT_FILE}"
  echo -e " - Análisis detallado: ${ANALYSIS_FILE}"
}

# Función para probar parámetros
test_parameter() {
  local file_path="$1"
  local param="$2"
  
  url="http://${BASE_URL}${file_path}?${param}=FUZZ"
  response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT" "$url")
  
  if [[ "$response_code" =~ ^(200|302|401|403|500)$ ]]; then
    echo -e "\n${GREEN}[+] Found:${NC} $url (HTTP $response_code)" | tee -a "$RESULTS_FILE"
    # Guardar contenido de la respuesta
    echo -e "=== URL: $url ===" >> "$CONTENT_FILE"
    curl -s "$url" >> "$CONTENT_FILE"
    echo -e "\n=== FIN DE RESPUESTA ===\n" >> "$CONTENT_FILE"
  fi
  
  ((CURRENT_TEST++))
  show_progress
  sleep "$DELAY"
}

# Calcular total de tests
calculate_total_tests() {
  TOTAL_TESTS=$(( ${#TARGET_FILES[@]} * $(wc -l < "$WORDLIST") ))
}

# Función principal
main() {
  # Inicializar archivos de salida
  echo -e "Resultados de Fuzzing - $(date)\n" > "$RESULTS_FILE"
  echo -e "Contenidos de respuestas - $(date)\n" > "$CONTENT_FILE"
  
  echo -e "${YELLOW}[*] Target: ${BASE_URL}${NC}"
  echo -e "${YELLOW}[*] Wordlist: ${WORDLIST}${NC}"
  echo -e "${YELLOW}[*] Archivos de salida:${NC}"
  echo -e " - URLs encontradas: ${RESULTS_FILE}"
  echo -e " - Contenidos: ${CONTENT_FILE}"
  echo -e " - Análisis: ${ANALYSIS_FILE}"
  
  calculate_total_tests
  echo -e "${YELLOW}[*] Total tests: ${TOTAL_TESTS}${NC}"
  
  # Realizar pruebas
  while IFS= read -r param || [ -n "$param" ]; do
    param_clean=$(echo "$param" | tr -d '\r\n' | xargs)
    [ -z "$param_clean" ] && continue
    
    for file in "${TARGET_FILES[@]}"; do
      test_parameter "$file" "$param_clean"
    done
  done < "$WORDLIST"
  
  # Analizar resultados
  analyze_results
}

main