#!/bin/bash

# Script de Fuzzing para parámetros ocultos en archivos PHP específicos
# URL base: 172.17.0.2
# Directorios objetivo: /vendor/composer y /vendor/firebase/php-jwt/src

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
BASE_URL="172.17.0.2"  # URL base del servidor
WORDLIST="wordlist_params.txt"  # Archivo con lista de parámetros a probar
OUTPUT="fuzz_results.txt"  # Archivo de salida para los resultados
DELAY=0.3  # Delay entre peticiones en segundos (evitar sobrecarga)

# Archivos específicos a analizar
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
    echo -e "${YELLOW}Uso:${NC} $0 [opciones]"
    echo -e "${YELLOW}Opciones:${NC}"
    echo -e "  -w <wordlist>    Wordlist personalizada (default: $WORDLIST)"
    echo -e "  -o <archivo>     Archivo de salida (default: $OUTPUT)"
    echo -e "  -h               Mostrar esta ayuda"
    exit 0
}

# Procesar parámetros
while getopts "w:o:h" opt; do
    case $opt in
        w) WORDLIST="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        h) show_help ;;
        *) echo -e "${RED}Opción inválida: -$OPTARG${NC}" >&2; exit 1 ;;
    esac
done

# Validaciones
if [ ! -f "$WORDLIST" ]; then
    echo -e "${RED}Error: No se encontró la wordlist $WORDLIST${NC}"
    exit 1
fi

# Función para probar un parámetro en una URL
test_parameter() {
    local file_path="$1"
    local param="$2"
    
    # Construir la URL
    url="http://${BASE_URL}${file_path}?${param}=FUZZ"
    
    # Realizar la petición (usando curl silencioso con timeout)
    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url")
    
    # Analizar respuesta
    if [[ "$response" =~ ^(200|302|401|403|500)$ ]]; then
        echo -e "${GREEN}[+] Parámetro potencial encontrado:${NC} $url (HTTP $response)" | tee -a "$OUTPUT"
        # Opcional: guardar también el contenido de la respuesta para análisis posterior
        curl -s "$url" >> "${OUTPUT}_content.txt"
        echo "---------" >> "${OUTPUT}_content.txt"
    fi
    
    # Delay para no saturar el servidor
    sleep "$DELAY"
}

# Función principal de fuzzing
fuzz_files() {
    echo -e "${YELLOW}[*] Iniciando fuzzing en archivos específicos${NC}"
    echo -e "${YELLOW}[*] URL base: http://${BASE_URL}${NC}"
    echo -e "${YELLOW}[*] Usando wordlist: $WORDLIST${NC}"
    echo -e "${YELLOW}[*] Resultados se guardarán en: $OUTPUT${NC}"
    echo "" > "$OUTPUT"  # Limpiar archivo de resultados
    echo "" > "${OUTPUT}_content.txt"  # Limpiar archivo de contenidos
    
    # Procesar cada archivo objetivo
    for file in "${TARGET_FILES[@]}"; do
        echo -e "${YELLOW}[*] Procesando archivo: $file${NC}"
        
        # Verificar si el archivo existe
        if [ ! -f "$file" ]; then
            echo -e "${RED}[-] Archivo no encontrado: $file${NC}" | tee -a "$OUTPUT"
            continue
        fi
        
        # Probar cada parámetro de la wordlist
        while IFS= read -r param; do
            # Eliminar espacios y líneas vacías
            param_clean=$(echo "$param" | tr -d "[:space:]")
            [ -z "$param_clean" ] && continue
            
            # Probar el parámetro
            test_parameter "$file" "$param_clean"
        done < "$WORDLIST"
    done
    
    echo -e "${YELLOW}[*] Fuzzing completado${NC}"
    echo -e "${YELLOW}[*] Revisa los resultados en $OUTPUT${NC}"
    echo -e "${YELLOW}[*] Contenidos de respuestas en ${OUTPUT}_content.txt${NC}"
}

# Ejecutar
fuzz_files


# Notas:
# - Asegúrate de tener permisos para ejecutar el script.
#   chmod +x specific_fuzzer.sh
# - Puedes ajustar el tiempo de espera entre peticiones modificando la variable DELAY.
# - La wordlist debe contener parámetros comunes que podrían ser vulnerables.
# - El script guarda los resultados en un archivo de texto y también captura el contenido de las respuestas.
# - Puedes personalizar la URL base y los archivos específicos a analizar según tus necesidades.
# - Asegúrate de tener instalado curl y permisos para acceder a los archivos PHP.
# - Este script es un ejemplo básico y puede ser mejorado con más funcionalidades.
# - Considera agregar más validaciones y manejo de errores según sea necesario.
# - Este script es para fines educativos y de pruebas de seguridad. No lo uses sin autorización.
# - Asegúrate de tener permisos para realizar pruebas de seguridad en el servidor objetivo.
# - Este script no es responsable de ningún daño o problema causado por su uso indebido.
# - Usa este script bajo tu propio riesgo y asegúrate de cumplir con las leyes y regulaciones locales.

# Uso
# ./specific_fuzzer.sh -w jwt_wordlist.txt -o jwt_results.txt

# -w jwt_wordlist.txt: Especifica una wordlist personalizada para parámetros.
# -o jwt_results.txt: Especifica un archivo de salida para los resultados.
# -h: Muestra la ayuda del script.
# - Puedes ejecutar el script sin opciones para usar la configuración predeterminada.
# - Asegúrate de que el servidor esté en funcionamiento y accesible antes de ejecutar el script.
