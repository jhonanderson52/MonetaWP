# MonetaWP

Tema WordPress diseñado para la creación rápida de sitios de contenido monetizables con AdSense y otros proveedores de anuncios. Incluye instalador automático para VPS Ubuntu.

---

## Instalación en un comando

```bash
curl -fsSL https://raw.githubusercontent.com/jhonanderson52/MonetaWP/main/install.sh -o /tmp/install.sh && sudo bash /tmp/install.sh
```

> Ejecutar como **root** o con **sudo** en un VPS Ubuntu 20.04 / 22.04.

---

## ¿Qué instala el script?

| Componente | Detalle |
|---|---|
| WordPress | Última versión compatible con el PHP del VPS |
| Tema | MonetaWP — optimizado para AdSense |
| Rank Math SEO | SEO técnico, sitemap XML |
| LiteSpeed Cache | Rendimiento y caché |
| Easy Table of Contents | Índice automático en artículos |
| Contact Form 7 | Formulario de contacto |
| Páginas AdSense | Privacidad, Cookies, Aviso Legal, Sobre Nosotros, Contacto |
| Contenido de muestra | 5 posts adaptados al nicho elegido |
| robots.txt | Archivo físico con referencia al sitemap |
| Virtual host | Apache o Nginx (detecta el activo) |
| SSL | Let's Encrypt (opcional) |

---

## Requisitos previos

- VPS Ubuntu 20.04 o 22.04
- Acceso SSH como `root` o usuario con `sudo`
- MySQL/MariaDB instalado
- Servidor web (Apache o Nginx) instalado
- El dominio apuntando a la IP del VPS (necesario para SSL)

---

## Flujo de instalación

El script hace preguntas y tú solo respondes:

```
Dominio (sin https://)      → mi-sitio.com
Nombre del sitio            → Mi Blog de Salud
Nicho del sitio             → salud
Usuario administrador WP    → admin
Email administrador         → correo@gmail.com
Contraseña administrador    → (oculta)
Nombre de la base de datos  → mi_sitio_db
Usuario MySQL               → root
Contraseña MySQL            → (oculta)
¿Configurar SSL?            → s
```

---

## Instalación alternativa (con wget)

```bash
wget -O /tmp/install.sh https://raw.githubusercontent.com/jhonanderson52/MonetaWP/main/install.sh && sudo bash /tmp/install.sh
```

---

## Después de instalar

1. Accede a `https://tu-dominio.com/wp-admin/`
2. Configura **Apariencia → Personalizar** con imágenes y colores
3. Añade tu código de AdSense en **Apariencia → Personalizar → AdSense**
4. Configura la **Indexación Masiva** en **Herramientas → Indexación Masiva**
5. Envía el sitemap a Google Search Console

---

## Seguridad del instalador

- **No toca** sitios existentes en el VPS
- **No actualiza** paquetes del sistema sin confirmación
- **No instala PHP** si ya existe (usa la versión del VPS)
- Muestra todos los sitios existentes antes de continuar

---

## Licencia

MIT License — libre para uso comercial y personal.
