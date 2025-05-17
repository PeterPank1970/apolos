#!/bin/bash

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración por defecto
BASE_URL="172.17.0.2"
DELAY=0.3

# Procesar argumentos
while getopts "u:d:h" opt; do
  case $opt in
    u) BASE_URL="$OPTARG" ;;
    d) DELAY="$OPTARG" ;;
    h)
      echo -e "${YELLOW}Uso:${NC} $0 [-u base_url] [-d delay]"
      exit 0
      ;;
    *) ;;
  esac
done

# Archivos específicos a analizar
declare -a TARGET_FILES=(
    "/vendor/composer/ClassLoader.php"
    "/vendor/composer/InstalledVersions.php"
    "/vendor/composer/autoload_classmap.php"
    "/vendor/composer/autoload_namespaces.php"
    "/vendor/composer/autoload_psr4.php"
    "/vendor/composer/autoload_real.php"
    "/vendor/composer/autoload_static.php"
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

OUTPUT_DIR="headers_analysis"
mkdir -p "$OUTPUT_DIR"

declare -a OK_FILES
declare -a FAIL_FILES

extract_headers() {
    local url="$1"
    local output_file="$2"

    echo -e "\n${CYAN}🔍 Analizando:${NC} $url"

    # Extraer cabeceras con curl y guardar en archivo
    http_code=$(curl -I -s -w "%{http_code}" -o "$output_file" "$url")
    if [[ "$http_code" =~ ^2|3 ]]; then
        echo -e "${GREEN}✅ Cabeceras guardadas en:${NC} $output_file"
        grep -E 'HTTP|X-Powered|Server|Content-Type|PHP|Auth' "$output_file" | sed 's/^/    /'
        OK_FILES+=("$url")
    else
        echo -e "${RED}❌ Error al acceder a:${NC} $url (HTTP $http_code)"
        FAIL_FILES+=("$url ($http_code)")
        rm -f "$output_file"
    fi
}

for file in "${TARGET_FILES[@]}"; do
    output_file="${OUTPUT_DIR}/${file//\//_}.headers"
    extract_headers "http://${BASE_URL}${file}" "$output_file"
    sleep "$DELAY"
done

echo -e "\n${YELLOW}📊 Análisis completado.${NC} Todos los resultados guardados en: $OUTPUT_DIR/"
echo -e "${GREEN}Accesos correctos:${NC} ${#OK_FILES[@]}"
for f in "${OK_FILES[@]}"; do echo "  $f"; done
echo -e "${RED}Accesos fallidos:${NC} ${#FAIL_FILES[@]}"
for f in "${FAIL_FILES[@]}"; do echo "  $f"; done