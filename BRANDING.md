# Guía de Personalización de Marca (Branding) - DocuSeal

Esta guía detalla todos los elementos que necesitas cambiar para implementar tu propia marca en DocuSeal.

## 📋 Índice Rápido

1. [Configuración Principal](#1-configuración-principal)
2. [Logos e Imágenes](#2-logos-e-imágenes)
3. [Colores y Tema](#3-colores-y-tema)
4. [Correos Electrónicos](#4-correos-electrónicos)
5. [Textos y Traducciones](#5-textos-y-traducciones)
6. [URLs y Enlaces](#6-urls-y-enlaces)
7. [Páginas y Vistas](#7-páginas-y-vistas)

---

## 1. Configuración Principal

### 📁 Archivo: `lib/docuseal.rb`

Este es el **archivo más importante** para el branding. Cambia estos valores:

```ruby
# Línea 9 - Nombre del producto
PRODUCT_NAME = 'TuMarca'  # Cambiar de 'DocuSeal'

# Línea 5 - URL principal
PRODUCT_URL = 'https://www.tumarca.com'  # Cambiar de 'https://www.docuseal.com'

# Línea 16 - Email de soporte
SUPPORT_EMAIL = 'soporte@tumarca.com'  # Cambiar de 'support@docuseal.com'

# Línea 11 - URL de GitHub (opcional)
GITHUB_URL = 'https://github.com/tuorg/tumarca'

# Línea 12 - Discord (opcional)
DISCORD_URL = 'https://discord.gg/tuservidor'

# Línea 13-14 - Twitter/X (opcional)
TWITTER_URL = 'https://twitter.com/tumarca'
TWITTER_HANDLE = '@tumarca'
```

### Variables de Entorno

Puedes usar variables de entorno para algunos valores:

```bash
PRODUCT_EMAIL_URL=https://www.tumarca.com
```

---

## 2. Logos e Imágenes

### 📁 Directorio: `public/`

Reemplaza estos archivos con tu propia marca:

#### Logo Principal
- **`public/logo.svg`** - Logo principal (SVG recomendado)

#### Favicons (Iconos de navegador)
- **`public/favicon.ico`** - Icono principal (16x16, 32x32, 48x48)
- **`public/favicon-16x16.png`**
- **`public/favicon-32x32.png`**
- **`public/favicon-96x96.png`**

#### Iconos de Apple
- **`public/apple-touch-icon.png`**
- **`public/apple-touch-icon-precomposed.png`**
- **`public/apple-icon-180x180.png`**

#### Imagen de Vista Previa Social
- **`public/preview.png`** - Imagen para compartir en redes sociales (1200x630px recomendado)

### 🎨 Logo SVG en Vistas

Si usas el logo SVG embebido en las vistas, también actualiza:

**📁 Archivo: `app/views/shared/_logo.html.erb`**

```erb
<!-- Reemplaza el SVG completo con tu logo -->
<svg>...</svg>
```

---

## 3. Colores y Tema

### 📁 Archivo: `tailwind.config.js`

Personaliza los colores del tema DaisyUI (líneas 8-21):

```javascript
daisyui: {
  themes: [
    {
      docuseal: {  // Puedes renombrar esto
        primary: '#tu-color-primario',      // Era: #e4e0e1
        secondary: '#tu-color-secundario',  // Era: #ef9fbc
        accent: '#tu-color-acento',         // Era: #eeaf3a
        neutral: '#tu-color-neutral',       // Era: #291334
        'base-100': '#tu-fondo',           // Era: #faf7f5
        'base-200': '#tu-fondo-claro',     // Era: #efeae6
        'base-300': '#tu-fondo-oscuro',    // Era: #e7e2df
        'base-content': '#tu-texto',       // Era: #291334
      }
    }
  ]
}
```

### Color del Tema del Navegador

**📁 Archivo: `app/views/shared/_meta.html.erb`**

```erb
<!-- Línea 30 -->
<meta name="theme-color" content="#tu-color">
```

### Colores del PWA Manifest

**📁 Archivo: `app/views/pwa/manifest.json.erb`**

```erb
"theme_color": "#tu-color",
"background_color": "#tu-color"
```

---

## 4. Correos Electrónicos

### 📁 Archivo: `app/mailers/application_mailer.rb`

```ruby
# Línea 4 - Remitente por defecto
default from: 'Tu Marca <noreply@tumarca.com>'
```

### Plantillas de Email

**📁 Directorio: `app/views/personalization_settings/`**

Estas vistas permiten personalizar emails por cuenta:
- `_signature_request_email_form.html.erb`
- `_submitter_completed_email_form.html.erb`
- `_documents_copy_email_form.html.erb`

### Footer de Emails

**📁 Archivo: `app/views/shared/_email_attribution.html.erb`**

Modifica el texto del pie de página de los emails que usa:
- `Docuseal::PRODUCT_EMAIL_URL`
- Textos localizados

---

## 5. Textos y Traducciones

### 📁 Archivo: `config/locales/i18n.yml`

Busca y reemplaza las referencias a "DocuSeal" en estos keys (alrededor de la línea 643):

```yaml
# Ejemplos de keys a actualizar:
welcome_to_docuseal: "Bienvenido a Tu Marca"
open_source_documents_software: "software de documentos de código abierto"
sent_using_product_name_html: 'Enviado usando <a href="%{product_url}">%{product_name}</a>'
docuseal_trusted_signature: "Firma de Confianza de Tu Marca"
docuseal_support: "Soporte de Tu Marca"
```

**Nota:** Hay traducciones para múltiples idiomas (ES, IT, FR, PT, DE, NL, PL, UK, CS, HE, AR, KO, JA).

### Títulos de Página

**📁 Archivo: `app/views/layouts/_head_tags.html.erb`**

```erb
<!-- Línea 2 -->
<%= content_for(:html_title) || (signed_in? ? 'Tu Marca' : 'Tu Marca | Firma Digital de Documentos') %>
```

**📁 Archivo: `app/views/shared/_meta.html.erb`**

```erb
<!-- Línea 4 -->
<% title = content_for(:html_title) || 'Tu Marca | ...' %>

<!-- Línea 11 - Open Graph -->
<meta property="og:site_name" content="Tu Marca">

<!-- Líneas 22-23 - Twitter -->
<meta name="twitter:creator" content="@tumarca">
<meta name="twitter:site" content="@tumarca">
```

---

## 6. URLs y Enlaces

### Enlaces de Navegación

**📁 Archivo: `app/views/shared/_navbar.html.erb`**

```erb
<!-- Línea 14 -->
<%= link_to 'Regístrate', 'https://www.tumarca.com/sign_up' %>
```

### Página de Inicio (Landing)

**📁 Archivo: `app/views/pages/landing.html.erb`**

```erb
<!-- Línea 8 - Título -->
<h1>Tu Marca</h1>

<!-- Línea 17 - Descripción -->
Una plataforma auto-hospedada para firma digital de documentos...

<!-- Línea 30 - Enlace de instalación -->
<a href="https://www.tumarca.com/install">

<!-- Línea 70 - Enlace GitHub -->
<%= link_to Docuseal::GITHUB_URL %>
```

### Footer "Powered By"

**📁 Archivo: `app/views/shared/_powered_by.html.erb`**

```erb
<!-- Línea 12 -->
<a href="<%= Docuseal::PRODUCT_URL %>">
  <%= Docuseal.product_name %>
</a> - <%= t('open_source_documents_software') %>
```

**Nota:** Este footer aparece en formularios públicos. Puedes hacerlo opcional por cuenta.

### Componentes Vue.js

**📁 Archivo: `app/javascript/submission_form/completed.vue`**

```javascript
// Línea 69
href: "https://github.com/tuorg/tumarca"

// Línea 79
href: "https://tumarca.com/sign_up"

// Línea 94
href: "https://www.tumarca.com/start"
```

---

## 7. Páginas y Vistas

### Logotipos en Vistas

**📁 Archivos:**
- `app/views/shared/_title.html.erb` (línea 2)
- `app/views/submit_form/_docuseal_logo.html.erb`
- `app/views/start_form/_docuseal_logo.html.erb`

```erb
<span>Tu Marca</span>
<!-- O mejor aún: -->
<span><%= Docuseal.product_name %></span>
```

### PWA Manifest

**📁 Archivo: `app/views/pwa/manifest.json.erb`**

```erb
{
  "name": "Tu Marca",
  "short_name": "Tu Marca",
  "description": "Tu Marca es una plataforma de código abierto para...",
  "theme_color": "#tu-color",
  "background_color": "#tu-color"
}
```

### Configuración de Certificados

**📁 Archivo: `app/controllers/esign_settings_controller.rb`**

```ruby
# Línea 4
DEFAULT_CERT_NAME = 'Tu Marca Self-Host Autogenerated'
```

---

## ✅ Checklist de Personalización

Usa esta lista para asegurarte de que has cambiado todo:

### Configuración Base
- [ ] `lib/docuseal.rb` - PRODUCT_NAME
- [ ] `lib/docuseal.rb` - PRODUCT_URL
- [ ] `lib/docuseal.rb` - SUPPORT_EMAIL
- [ ] `lib/docuseal.rb` - GITHUB_URL (opcional)
- [ ] `lib/docuseal.rb` - DISCORD_URL (opcional)
- [ ] `lib/docuseal.rb` - TWITTER_URL y TWITTER_HANDLE (opcional)

### Logos e Imágenes
- [ ] `public/logo.svg`
- [ ] `public/favicon.ico`
- [ ] `public/favicon-*.png` (todos los tamaños)
- [ ] `public/apple-*.png` (todos los iconos Apple)
- [ ] `public/preview.png`
- [ ] `app/views/shared/_logo.html.erb` (si usas SVG embebido)

### Colores
- [ ] `tailwind.config.js` - Tema DaisyUI
- [ ] `app/views/shared/_meta.html.erb` - theme-color
- [ ] `app/views/pwa/manifest.json.erb` - theme_color y background_color

### Emails
- [ ] `app/mailers/application_mailer.rb` - default from
- [ ] `app/views/shared/_email_attribution.html.erb`

### Textos
- [ ] `config/locales/i18n.yml` - Referencias a DocuSeal
- [ ] `app/views/layouts/_head_tags.html.erb` - Título
- [ ] `app/views/shared/_meta.html.erb` - Meta tags y Twitter

### Enlaces y Páginas
- [ ] `app/views/pages/landing.html.erb` - Página de inicio
- [ ] `app/views/shared/_powered_by.html.erb` - Footer
- [ ] `app/views/shared/_navbar.html.erb` - Enlaces de navegación
- [ ] `app/javascript/submission_form/completed.vue` - Enlaces Vue.js

### PWA y Otros
- [ ] `app/views/pwa/manifest.json.erb` - Manifest
- [ ] `app/controllers/esign_settings_controller.rb` - Nombre de certificado
- [ ] `README.md` - Documentación (opcional)

---

## 🚀 Comandos Útiles Después de Cambiar Branding

Después de hacer cambios:

```bash
# Recompilar assets
bundle exec rails assets:precompile

# Si usas Docker
docker compose -f docker-compose.dev.yml down
docker compose -f docker-compose.dev.yml up --build

# Limpiar cache de Rails
bundle exec rails tmp:clear
bundle exec rails restart
```

---

## 💡 Mejores Prácticas

1. **Usa Variables de Entorno:** Para valores sensibles como URLs y emails
2. **Mantén Copias:** Guarda copias de los logos originales antes de reemplazarlos
3. **Prueba en Todos los Idiomas:** Si tu app es multiidioma, verifica traducciones
4. **Verifica Emails:** Envía emails de prueba para ver cómo se ve tu marca
5. **PWA:** Borra el caché del navegador después de cambiar el manifest
6. **Git:** Considera usar `.env` o archivos de configuración local (no comiteados) para URLs

---

## 📝 Notas Importantes

- **White-Label Completo:** DocuSeal Pro ofrece opciones de white-label por cuenta
- **Atribución:** Si usas la versión open source, considera mantener alguna atribución
- **Licencia:** Revisa la licencia AGPLv3 para cumplir con los términos
- **Updates:** Al actualizar desde upstream, revisa conflictos en archivos de branding

---

## 🔧 Automatización (Opcional)

Puedes crear un script para automatizar algunos cambios:

```bash
#!/bin/bash
# branding-setup.sh

NEW_BRAND="Tu Marca"
NEW_URL="https://www.tumarca.com"
NEW_EMAIL="soporte@tumarca.com"

# Usa sed o herramientas similares para reemplazar valores
# Ejemplo:
# sed -i '' "s/DocuSeal/$NEW_BRAND/g" lib/docuseal.rb
```

---

## 📚 Recursos Adicionales

- [Documentación de DaisyUI](https://daisyui.com/docs/themes/)
- [Generador de Favicons](https://realfavicongenerator.net/)
- [Herramienta de PWA Manifest](https://www.simicart.com/manifest-generator.html/)
