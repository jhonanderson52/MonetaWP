#!/usr/bin/env bash
# ==============================================================================
# MonetaWP Installer v1.0
# Instala WordPress + tema MonetaWP + plugins + páginas AdSense en un VPS Ubuntu
# Uso: curl -fsSL https://raw.githubusercontent.com/jhonanderson52/MonetaWP/main/install.sh -o /tmp/install.sh && sudo bash /tmp/install.sh
# ==============================================================================

THEME_URL="https://github.com/jhonanderson52/MonetaWP/raw/main/theme/MonetaWP.zip"
WP_USER="www-data"

# ── A. Banner ─────────────────────────────────────────────────────────────────
clear
echo ""
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║          MonetaWP Installer  v1.0                   ║"
echo "  ║   WordPress + Tema + Plugins + Páginas AdSense      ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo ""

# ── B. Funciones de utilidad ──────────────────────────────────────────────────
green()  { echo -e "\e[32m$*\e[0m"; }
yellow() { echo -e "\e[33m$*\e[0m"; }
red()    { echo -e "\e[31m$*\e[0m"; }
step()   { echo ""; echo -e "\e[36m▶ $*\e[0m"; }

die() { red "❌ ERROR: $*"; exit 1; }

if [[ $EUID -ne 0 ]]; then
    die "Ejecuta el script como root: sudo bash /tmp/install.sh"
fi

# ── B. Verificación de requisitos ─────────────────────────────────────────────
step "Verificando entorno del VPS..."

# Protección de sitios existentes
EXISTING_SITES=$(ls /var/www/html/ 2>/dev/null | grep -v "^html$\|^index.html$" || true)
if [[ -n "$EXISTING_SITES" ]]; then
    yellow "⚠  Sitios existentes detectados en /var/www/html/:"
    echo "$EXISTING_SITES" | sed 's/^/     - /'
    echo ""
    yellow "   El instalador NO modificará ninguno de esos directorios."
    echo ""
fi

# PHP: detectar versión instalada
PHP_BIN=$(command -v php 2>/dev/null || true)
if [[ -n "$PHP_BIN" ]]; then
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)
    green "  ✓ PHP $PHP_VER detectado"
else
    yellow "  ⚠ PHP no encontrado en este VPS."
    echo ""
    echo "  Instalar PHP puede afectar otros servicios si los hay."
    read -p "  ¿Instalar PHP ahora? [s/N]: " INSTALL_PHP
    if [[ "${INSTALL_PHP,,}" != "s" ]]; then die "PHP es necesario para WordPress. Instálalo manualmente y vuelve a ejecutar."; fi
    apt-get install -y php php-mysql php-curl php-xml php-mbstring php-zip php-gd php-intl 2>&1 | grep -E 'install|already'
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    green "  ✓ PHP $PHP_VER instalado"
fi

# WordPress compatible con la versión de PHP
PHP_MAJOR=$(echo "$PHP_VER" | cut -d. -f1)
PHP_MINOR=$(echo "$PHP_VER" | cut -d. -f2)
if [[ "$PHP_MAJOR" -eq 7 && "$PHP_MINOR" -eq 4 ]]; then
    WP_VERSION="6.4.4"
    yellow "  ℹ PHP 7.4 detectado → instalando WordPress $WP_VERSION (última compatible)"
else
    WP_VERSION="latest"
fi

# Servidor web: Apache > Nginx, sin instalar ni modificar nada
if systemctl is-active --quiet apache2 2>/dev/null; then
    WEB_SERVER="apache2"
    green "  ✓ Apache detectado"
elif systemctl is-active --quiet nginx 2>/dev/null; then
    WEB_SERVER="nginx"
    green "  ✓ Nginx detectado"
else
    yellow "  ⚠ No se detectó servidor web activo (Apache/Nginx)."
    echo "  Opciones:"
    echo "    1) Instalar Apache"
    echo "    2) Instalar Nginx"
    echo "    3) Cancelar (instalo manualmente)"
    read -p "  Elige [1/2/3]: " WS_CHOICE
    case "$WS_CHOICE" in
        1) apt-get install -y apache2 && a2enmod rewrite; WEB_SERVER="apache2" ;;
        2) apt-get install -y nginx; WEB_SERVER="nginx" ;;
        *) die "Instala un servidor web y vuelve a ejecutar." ;;
    esac
fi

# MySQL
command -v mysql &>/dev/null || die "MySQL/MariaDB no está instalado. Instálalo con: apt-get install -y mysql-server"
green "  ✓ MySQL detectado"

# curl y unzip (solo si faltan, sin tocar otros paquetes)
for pkg in curl unzip; do
    command -v $pkg &>/dev/null || apt-get install -y $pkg 2>&1 | grep -E 'install|already'
done

# WP-CLI (binario standalone, no afecta el sistema)
if ! command -v wp &>/dev/null; then
    step "Instalando WP-CLI..."
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
    green "  ✓ WP-CLI instalado"
else
    green "  ✓ WP-CLI detectado ($(wp --version 2>/dev/null | head -1))"
fi

# ── C. Prompts interactivos ───────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────────────────────"
echo "  Configura tu nuevo sitio"
echo "  ─────────────────────────────────────────────────────"
echo ""

read -p "  Dominio (sin https://, ej: mi-sitio.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then die "El dominio es obligatorio."; fi

# Verificar que el dominio no existe ya
if [[ -d "/var/www/html/$DOMAIN" ]]; then
    die "Ya existe /var/www/html/$DOMAIN. Elige otro dominio o elimina ese directorio."
fi

read -p "  Nombre del sitio (ej: Mi Blog de Salud): " SITE_NAME
if [[ -z "$SITE_NAME" ]]; then SITE_NAME="Mi Sitio Web"; fi

read -p "  Nicho del sitio (ej: salud, finanzas, tecnología): " NICHE
if [[ -z "$NICHE" ]]; then NICHE="información"; fi

read -p "  Usuario administrador WordPress (ej: admin): " WP_ADMIN_USER
if [[ -z "$WP_ADMIN_USER" ]]; then WP_ADMIN_USER="admin"; fi

read -p "  Email administrador: " WP_ADMIN_EMAIL
if [[ -z "$WP_ADMIN_EMAIL" ]]; then die "El email es obligatorio."; fi

read -s -p "  Contraseña administrador: " WP_ADMIN_PASS; echo ""
if [[ -z "$WP_ADMIN_PASS" ]]; then die "La contraseña es obligatoria."; fi

echo ""
echo "  ─── Base de datos ────────────────────────────────────"
read -p "  Nombre de la base de datos (ej: ${DOMAIN//./_}_db): " DB_NAME
if [[ -z "$DB_NAME" ]]; then DB_NAME="${DOMAIN//./_}_db"; fi

read -p "  Usuario MySQL (ej: root): " DB_USER_MYSQL
if [[ -z "$DB_USER_MYSQL" ]]; then DB_USER_MYSQL="root"; fi

DB_PASS_MYSQL=""
DB_MYSQL_OK=0
for _attempt in 1 2 3; do
    read -s -p "  Contraseña MySQL (intento $_attempt/3): " DB_PASS_MYSQL; echo ""
    if mysql -u "$DB_USER_MYSQL" -p"$DB_PASS_MYSQL" -e "SELECT 1;" &>/dev/null 2>&1; then
        green "  ✓ Conexión MySQL verificada"
        DB_MYSQL_OK=1
        break
    else
        if [[ $_attempt -lt 3 ]]; then
            red "  ✗ Contraseña incorrecta, intenta de nuevo."
        else
            die "Contraseña MySQL incorrecta después de 3 intentos. Instalación cancelada."
        fi
    fi
done

DB_WP_USER="${DOMAIN//./_}_wp"
# Generar contraseña que cumple cualquier política MySQL (upper+lower+digit+special)
DB_WP_PASS="Mwp$(tr -dc 'a-z' </dev/urandom | head -c 6)$(tr -dc 'A-Z' </dev/urandom | head -c 4)$(tr -dc '0-9' </dev/urandom | head -c 4)@$(tr -dc 'a-z' </dev/urandom | head -c 3)"

echo ""
echo "  ─── SSL ──────────────────────────────────────────────"
read -p "  ¿Configurar SSL con Let's Encrypt? [s/N]: " SETUP_SSL

echo ""
echo "  ─────────────────────────────────────────────────────"
echo "  Resumen de instalación:"
echo "    Dominio:    https://$DOMAIN"
echo "    Sitio:      $SITE_NAME"
echo "    Nicho:      $NICHE"
echo "    WP Admin:   $WP_ADMIN_USER"
echo "    PHP:        $PHP_VER"
echo "    WordPress:  $WP_VERSION"
echo "    Servidor:   $WEB_SERVER"
echo "  ─────────────────────────────────────────────────────"
read -p "  ¿Iniciar instalación? [S/n]: " CONFIRM_INSTALL
if [[ "${CONFIRM_INSTALL,,}" == "n" ]]; then echo "Instalación cancelada."; exit 0; fi

WP="sudo -u $WP_USER wp --path=/var/www/html/$DOMAIN"

# ── D. Base de datos ──────────────────────────────────────────────────────────
step "Creando base de datos..."
# Bajar temporalmente la política de contraseñas MySQL si está activa
mysql -u "$DB_USER_MYSQL" -p"$DB_PASS_MYSQL" -e "SET GLOBAL validate_password.policy=LOW; SET GLOBAL validate_password.length=8;" 2>/dev/null || \
mysql -u "$DB_USER_MYSQL" -p"$DB_PASS_MYSQL" -e "SET GLOBAL validate_password_policy=LOW; SET GLOBAL validate_password_length=8;" 2>/dev/null || true

mysql -u "$DB_USER_MYSQL" -p"$DB_PASS_MYSQL" <<SQL 2>/dev/null
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_WP_USER'@'localhost' IDENTIFIED BY '$DB_WP_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_WP_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

# Verificar que la BD se creó correctamente
DB_CHECK=$(mysql -u "$DB_USER_MYSQL" -p"$DB_PASS_MYSQL" -sse "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME';" 2>/dev/null)
if [[ -z "$DB_CHECK" ]]; then
    die "No se pudo crear la base de datos '$DB_NAME'. Verifica usuario y contraseña MySQL."
fi
green "  ✓ Base de datos '$DB_NAME' creada"

# ── E. Directorio web ─────────────────────────────────────────────────────────
step "Creando directorio del sitio..."
mkdir -p /var/www/html/$DOMAIN
chown -R $WP_USER:$WP_USER /var/www/html/$DOMAIN
green "  ✓ /var/www/html/$DOMAIN creado"

# ── F. WordPress ──────────────────────────────────────────────────────────────
step "Descargando WordPress $WP_VERSION..."
sudo -u $WP_USER wp --path=/var/www/html/$DOMAIN core download \
    --locale=es_ES \
    $([ "$WP_VERSION" != "latest" ] && echo "--version=$WP_VERSION") \
    --force --quiet
green "  ✓ WordPress descargado"

# ── G. wp-config.php ─────────────────────────────────────────────────────────
step "Configurando wp-config.php..."
sudo -u $WP_USER wp --path=/var/www/html/$DOMAIN config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_WP_USER" \
    --dbpass="$DB_WP_PASS" \
    --dbhost="localhost" \
    --locale=es_ES \
    --quiet
$WP config set WP_DEBUG false --raw --quiet

if [[ ! -f "/var/www/html/$DOMAIN/wp-config.php" ]]; then
    die "wp-config.php no se pudo crear. Verifica las credenciales de la base de datos."
fi
green "  ✓ wp-config.php creado"

# ── WordPress install ──────────────────────────────────────────────────────────
step "Instalando WordPress..."
$WP core install \
    --url="http://$DOMAIN" \
    --title="$SITE_NAME" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --admin_password="$WP_ADMIN_PASS" \
    --skip-email --quiet
green "  ✓ WordPress instalado"

# ── H. Tema MonetaWP ─────────────────────────────────────────────────────────
step "Instalando tema MonetaWP..."
$WP theme install "$THEME_URL" --activate --quiet
green "  ✓ Tema MonetaWP activado"

# ── I. Plugins ────────────────────────────────────────────────────────────────
step "Instalando plugins..."
PLUGINS_RAW="https://raw.githubusercontent.com/jhonanderson52/MonetaWP/main/plugins"

install_plugin() {
    local slug=$1 label=$2 github_zip=$3

    if [[ -n "$github_zip" ]]; then
        # Descargar con curl primero (WP-CLI no sigue bien redirects de GitHub)
        local tmp_zip="/tmp/${github_zip}"
        curl -fsSL -o "$tmp_zip" "$PLUGINS_RAW/$github_zip" 2>/dev/null
        $WP plugin install "$tmp_zip" --activate --force 2>/dev/null
        rm -f "$tmp_zip"
    else
        $WP plugin install "$slug" --activate --force 2>/dev/null
    fi

    if $WP plugin is-installed "$slug" 2>/dev/null; then
        green "    ✓ $label"
    else
        yellow "    ✗ $label falló. Instala manualmente: wp plugin install $slug --activate"
    fi
}

install_plugin "seo-by-rank-math"         "Rank Math SEO"          "seo-by-rank-math.zip"
install_plugin "litespeed-cache"          "LiteSpeed Cache"        ""
install_plugin "easy-table-of-contents"   "Easy Table of Contents" ""
install_plugin "contact-form-7"           "Contact Form 7"         "contact-form-7.zip"

# Eliminar plugins por defecto de WordPress que no se necesitan
step "Eliminando plugins innecesarios..."
$WP plugin delete hello akismet 2>/dev/null && green "  ✓ Hello Dolly y Akismet eliminados" || true

# ── J. Limpiar páginas automáticas ────────────────────────────────────────────
step "Eliminando páginas automáticas de WordPress y plugins..."
# WordPress instala "Página de ejemplo" y "Política de privacidad" (borrador)
# Rank Math crea "Terms and Conditions" al activarse
for _slug in sample-page privacy-policy terms-and-conditions; do
    _ids=$($WP post list --post_type=page --name="$_slug" --format=ids 2>/dev/null || true)
    if [[ -n "$_ids" ]]; then
        $WP post delete $_ids --force --quiet 2>/dev/null || true
    fi
done
green "  ✓ Páginas automáticas eliminadas"

# ── J. Permalinks ─────────────────────────────────────────────────────────────
step "Configurando permalinks..."
$WP rewrite structure '/%postname%/' --hard --quiet
green "  ✓ Permalinks configurados"

# ── K. Páginas obligatorias AdSense ──────────────────────────────────────────
step "Creando páginas obligatorias..."

PRIV_ID=$($WP post create --post_type=page --post_status=publish --post_title="Política de Privacidad" --post_name="politica-de-privacidad" --porcelain --post_content="<p>En <strong>$SITE_NAME</strong> (<em>$DOMAIN</em>), accesible desde https://$DOMAIN, la privacidad de nuestros visitantes es de máxima importancia. Esta política de privacidad describe los tipos de información personal que se recibe y recopila, y cómo se usa.</p>
<h2>Información que recopilamos</h2>
<p>Podemos recopilar información personal como nombre y dirección de correo electrónico cuando te suscribes a nuestro boletín o nos contactas a través del formulario de contacto.</p>
<h2>Cookies</h2>
<p>Utilizamos cookies para mejorar la experiencia del usuario. Puedes configurar tu navegador para rechazar todas las cookies. Algunos servicios de terceros, como Google AdSense, también pueden usar cookies para personalizar anuncios.</p>
<h2>Anuncios</h2>
<p>Los anuncios de terceros que aparecen en este sitio pueden ser personalizados basándose en tu actividad de navegación. Para más información, visita <a href='https://policies.google.com/technologies/ads' target='_blank' rel='noopener'>la política de publicidad de Google</a>.</p>
<h2>Contacto</h2>
<p>Si tienes preguntas sobre esta política de privacidad, puedes contactarnos en: $WP_ADMIN_EMAIL</p>" 2>/dev/null)
green "    ✓ Política de Privacidad (ID: $PRIV_ID)"

COOK_ID=$($WP post create --post_type=page --post_status=publish --post_title="Política de Cookies" --post_name="politica-de-cookies" --porcelain --post_content="<p>Este sitio web utiliza cookies para mejorar tu experiencia de navegación. Al continuar usando el sitio, aceptas el uso de cookies de acuerdo con esta política.</p>
<h2>¿Qué son las cookies?</h2>
<p>Las cookies son pequeños archivos de texto que se almacenan en tu dispositivo cuando visitas un sitio web. Se usan para recordar tus preferencias y para analizar el tráfico del sitio.</p>
<h2>Tipos de cookies que usamos</h2>
<ul><li><strong>Cookies esenciales:</strong> Necesarias para el funcionamiento básico del sitio.</li>
<li><strong>Cookies analíticas:</strong> Nos ayudan a entender cómo los visitantes interactúan con el sitio (Google Analytics).</li>
<li><strong>Cookies publicitarias:</strong> Usadas por Google AdSense para mostrar anuncios relevantes.</li></ul>
<h2>Cómo desactivar las cookies</h2>
<p>Puedes controlar y/o eliminar cookies desde la configuración de tu navegador. Sin embargo, al desactivar las cookies, algunas partes del sitio pueden no funcionar correctamente.</p>" 2>/dev/null)
green "    ✓ Política de Cookies (ID: $COOK_ID)"

LEGAL_ID=$($WP post create --post_type=page --post_status=publish --post_title="Aviso Legal" --post_name="aviso-legal" --porcelain --post_content="<h2>Titularidad del sitio web</h2>
<p>El presente sitio web <strong>$DOMAIN</strong> es propiedad y está operado por <strong>$SITE_NAME</strong>.</p>
<h2>Condiciones de uso</h2>
<p>El acceso y uso de este sitio web implica la aceptación de los términos y condiciones aquí establecidos. Si no estás de acuerdo con alguno de ellos, te rogamos que no hagas uso del sitio.</p>
<h2>Propiedad intelectual</h2>
<p>Todos los contenidos del sitio web (textos, imágenes, diseño gráfico, código fuente, etc.) son propiedad de $SITE_NAME o de sus respectivos titulares, y están protegidos por las leyes de propiedad intelectual aplicables.</p>
<h2>Limitación de responsabilidad</h2>
<p>$SITE_NAME no se hace responsable de los daños y perjuicios que pudieran derivarse del uso de este sitio web o de la imposibilidad de acceder al mismo.</p>
<h2>Contacto</h2>
<p>Para cualquier consulta relacionada con este aviso legal: $WP_ADMIN_EMAIL</p>" 2>/dev/null)
green "    ✓ Aviso Legal (ID: $LEGAL_ID)"

ABOUT_ID=$($WP post create --post_type=page --post_status=publish --post_title="Sobre Nosotros" --post_name="sobre-nosotros" --porcelain --post_content="<p>Bienvenido a <strong>$SITE_NAME</strong>, tu fuente de información especializada en <strong>$NICHE</strong>.</p>
<h2>Nuestra misión</h2>
<p>Nos dedicamos a ofrecerte contenido de calidad, actualizado y fácil de entender sobre $NICHE. Nuestro objetivo es que encuentres la información que necesitas de manera rápida y confiable.</p>
<h2>¿Qué encontrarás aquí?</h2>
<p>En $SITE_NAME publicamos artículos, guías y análisis relacionados con $NICHE. Todo nuestro contenido está escrito pensando en ti, con lenguaje claro y ejemplos prácticos.</p>
<h2>Contáctanos</h2>
<p>¿Tienes alguna pregunta o sugerencia? Nos encantaría saber de ti. Puedes hacerlo a través de nuestra <a href='/contacto/'>página de contacto</a>.</p>" 2>/dev/null)
green "    ✓ Sobre Nosotros (ID: $ABOUT_ID)"

# Crear formulario CF7 básico y página de contacto
CF7_SHORTCODE="[contact-form-7 id=\"1\" title=\"Contact form 1\"]"
CONT_ID=$($WP post create --post_type=page --post_status=publish --post_title="Contacto" --post_name="contacto" --porcelain --post_content="<p>¿Tienes alguna pregunta, comentario o sugerencia? Completa el formulario y te responderemos a la brevedad posible.</p>
$CF7_SHORTCODE" 2>/dev/null)
green "    ✓ Contacto (ID: $CONT_ID)"

# ── L. Posts de muestra ───────────────────────────────────────────────────────
step "Creando contenido de muestra ($NICHE)..."

for i in 1 2 3 4 5; do
    $WP post create \
        --post_type=post \
        --post_status=publish \
        --post_title="Guía completa de $NICHE — Parte $i" \
        --post_content="<p>Esta es una guía de ejemplo sobre <strong>$NICHE</strong>. Aquí encontrarás información útil, consejos prácticos y recursos valiosos para adentrarte en el mundo de $NICHE.</p>
<h2>Introducción a $NICHE</h2>
<p>El campo de $NICHE está en constante evolución. En este artículo exploramos los conceptos clave que necesitas conocer para comenzar.</p>
<h2>Puntos clave</h2>
<ul>
<li>Comprender los fundamentos de $NICHE es el primer paso.</li>
<li>La práctica constante es esencial para mejorar.</li>
<li>Existen muchos recursos disponibles para aprender más.</li>
</ul>
<h2>Conclusión</h2>
<p>$NICHE ofrece grandes oportunidades para quienes están dispuestos a aprender y crecer. ¡Empieza hoy mismo!</p>" \
        --quiet 2>/dev/null
done
green "  ✓ 5 posts de muestra creados"

# ── M. Menú principal ─────────────────────────────────────────────────────────
step "Creando menú de navegación..."
MENU_ID=$($WP menu create "Principal" --porcelain 2>/dev/null)
$WP menu item add-post $MENU_ID $PRIV_ID --quiet 2>/dev/null
$WP menu item add-post $MENU_ID $COOK_ID --quiet 2>/dev/null
$WP menu item add-post $MENU_ID $LEGAL_ID --quiet 2>/dev/null
$WP menu item add-post $MENU_ID $ABOUT_ID --quiet 2>/dev/null
$WP menu item add-post $MENU_ID $CONT_ID --quiet 2>/dev/null
$WP menu location assign $MENU_ID primary --quiet 2>/dev/null
green "  ✓ Menú principal creado con 5 páginas"

# ── N. Customizer defaults ────────────────────────────────────────────────────
step "Aplicando configuración del tema..."
# Sobreescribir todos los textos hardcodeados del nicho original (convocatorias/becas)
# con texto genérico basado en el nicho y nombre del sitio ingresados por el usuario
$WP option update theme_mods_MonetaWP \
    "{
      \"mw_hero_title\":       \"Bienvenido a $SITE_NAME\",
      \"mw_hero_subtitle\":    \"Tu fuente de información sobre $NICHE. Contenido actualizado y fácil de entender.\",
      \"mw_hero_cta1_text\":   \"Ver artículos\",
      \"mw_hero_cta1_url\":    \"/blog/\",
      \"mw_hero_cta1_icon\":   \"📖\",
      \"mw_hero_cta2_text\":   \"Categorías\",
      \"mw_hero_cta2_url\":    \"/categoria/\",
      \"mw_hero_cta2_icon\":   \"🗂️\",
      \"mw_hero_cta3_text\":   \"Sobre Nosotros\",
      \"mw_hero_cta3_url\":    \"/sobre-nosotros/\",
      \"mw_hero_cta3_icon\":   \"ℹ️\",
      \"mw_pills_title\":      \"Explorar por Categoría\",
      \"mw_pills_enable\":     0,
      \"mw_featured_visible\": true,
      \"mw_featured_cta_text\":\"Ver todos los artículos →\",
      \"mw_featured_cta_url\": \"/blog/\",
      \"mw_latest_title\":     \"Últimos Artículos sobre $NICHE\",
      \"mw_latest_cta_text\":  \"Ver todos los artículos →\",
      \"mw_latest_cta_url\":   \"/blog/\",
      \"mw_nav_layout\":       \"right\"
    }" \
    --format=json --quiet 2>/dev/null
green "  ✓ Configuración del tema aplicada"

# ── O. robots.txt ─────────────────────────────────────────────────────────────
step "Creando robots.txt..."
cat > /var/www/html/$DOMAIN/robots.txt <<ROBOTS
User-agent: *
Allow: /
Disallow: /wp-admin/
Disallow: /wp-includes/
Disallow: /wp-content/plugins/
Disallow: /wp-content/themes/
Disallow: /xmlrpc.php
Disallow: /wp-login.php
Disallow: /feed/
Disallow: /?s=
Disallow: /search/

Sitemap: https://$DOMAIN/sitemap_index.xml
ROBOTS
chown $WP_USER:$WP_USER /var/www/html/$DOMAIN/robots.txt
green "  ✓ robots.txt creado"

# ── P. Rank Math básico ───────────────────────────────────────────────────────
step "Configurando Rank Math SEO..."
$WP option update rank_math_is_configured 1 --quiet 2>/dev/null || true
green "  ✓ Rank Math configurado"

# ── Q. Virtual host + SSL ─────────────────────────────────────────────────────
step "Configurando virtual host ($WEB_SERVER)..."

if [[ "$WEB_SERVER" == "apache2" ]]; then
    cat > /etc/apache2/sites-available/$DOMAIN.conf <<VHOST
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/html/$DOMAIN
    <Directory /var/www/html/$DOMAIN>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
VHOST
    a2ensite $DOMAIN.conf --quiet
    a2enmod rewrite --quiet
    service apache2 reload
    green "  ✓ VHost Apache configurado"
    # Refrescar .htaccess ahora que mod_rewrite está activo
    $WP rewrite flush --hard --quiet 2>/dev/null || true
    green "  ✓ Reglas de reescritura actualizadas"

elif [[ "$WEB_SERVER" == "nginx" ]]; then
    cat > /etc/nginx/sites-available/$DOMAIN <<VHOST
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/html/$DOMAIN;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VER-fpm.sock;
    }
    location ~ /\.ht { deny all; }
}
VHOST
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
    nginx -s reload
    green "  ✓ VHost Nginx configurado"
    $WP rewrite flush --hard --quiet 2>/dev/null || true
    green "  ✓ Reglas de reescritura actualizadas"
fi

# SSL con Let's Encrypt
if [[ "${SETUP_SSL,,}" == "s" ]]; then
    step "Configurando SSL con Let's Encrypt..."
    # Mapear nombre del servicio al plugin de certbot (apache2 → apache)
    if [[ "$WEB_SERVER" == "apache2" ]]; then
        CERTBOT_PLUGIN="apache"
    else
        CERTBOT_PLUGIN="nginx"
    fi

    if ! command -v certbot &>/dev/null; then
        apt-get install -y certbot python3-certbot-$CERTBOT_PLUGIN 2>&1 | grep -E 'install|already'
    fi

    # Detectar si www.DOMAIN resuelve — solo incluirlo si tiene DNS
    WWW_DOMAINS=""
    if host "www.$DOMAIN" &>/dev/null 2>&1; then
        WWW_DOMAINS="-d www.$DOMAIN"
    fi

    # Deshabilitar SSL vhost previo si existe (evita "addresses conflict" en reinsalaciones)
    if [[ -f "/etc/apache2/sites-available/$DOMAIN-le-ssl.conf" ]]; then
        a2dissite "$DOMAIN-le-ssl.conf" --quiet 2>/dev/null || true
    fi

    # Obtener/renovar certificado sin tocar el redirect (lo hacemos manualmente)
    if certbot --$CERTBOT_PLUGIN -d $DOMAIN $WWW_DOMAINS \
        --non-interactive --agree-tos -m $WP_ADMIN_EMAIL 2>/dev/null; then

        # Agregar redirect HTTP → HTTPS directamente en el vhost HTTP
        if [[ "$WEB_SERVER" == "apache2" ]]; then
            cat > /etc/apache2/sites-available/$DOMAIN.conf <<VHOST
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/html/$DOMAIN
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
VHOST
            service apache2 reload
        elif [[ "$WEB_SERVER" == "nginx" ]]; then
            # Nginx: agregar return 301 al server block de puerto 80
            sed -i 's|try_files.*|return 301 https://\$host\$request_uri;|' \
                /etc/nginx/sites-available/$DOMAIN 2>/dev/null
            nginx -s reload
        fi

        green "  ✓ SSL configurado y redirect HTTP→HTTPS activo"
        $WP option update siteurl "https://$DOMAIN" --quiet 2>/dev/null
        $WP option update home    "https://$DOMAIN" --quiet 2>/dev/null
        $WP rewrite flush --hard --quiet 2>/dev/null || true
    else
        yellow "  ⚠ SSL no configurado (¿el DNS apunta al VPS?)"
        yellow "    El sitio funciona en HTTP. Cuando el DNS esté listo ejecuta:"
        yellow "    certbot --$CERTBOT_PLUGIN -d $DOMAIN --non-interactive --agree-tos -m $WP_ADMIN_EMAIL"
    fi
fi

# ── R. Resumen final ──────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║              ✅ INSTALACIÓN COMPLETADA               ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo ""
echo "  🌐 Sitio web:       https://$DOMAIN"
echo "  ⚙️  Panel admin:    https://$DOMAIN/wp-admin/"
echo "  👤 Usuario:         $WP_ADMIN_USER"
echo "  📧 Email:           $WP_ADMIN_EMAIL"
echo ""
echo "  🔌 Plugins activos:"
echo "     - Rank Math SEO"
echo "     - LiteSpeed Cache"
echo "     - Easy Table of Contents"
echo "     - Contact Form 7"
echo ""
echo "  📄 Páginas creadas:"
echo "     - Política de Privacidad"
echo "     - Política de Cookies"
echo "     - Aviso Legal"
echo "     - Sobre Nosotros"
echo "     - Contacto"
echo ""
echo "  📝 5 posts de muestra sobre: $NICHE"
echo ""
yellow "  ⚠ PRÓXIMOS PASOS RECOMENDADOS:"
echo "  1. Configura Google AdSense → https://$DOMAIN/wp-admin/"
echo "  2. Añade credenciales Google en Herramientas → Indexación Masiva"
echo "  3. Verifica en Google Search Console"
echo "  4. Sube imágenes del Hero en Apariencia → Personalizar"
echo ""
green "  ¡Tu sitio está listo para generar ingresos! 🚀"
echo ""
