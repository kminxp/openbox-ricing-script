#!/usr/bin/env bash
# setup-openbox-completo.sh
# Script todo-en-uno para Debian (ejecutar desde TTY en una instalación mínima)
# - instala Openbox, jgmenu, Nitrogen, PCManFM, Terminator, LightDM (autologin),
#   herramientas multimedia y de red, lxappearance + Papirus icons,
#   scripts para mpv/yt-dlp (480p), descarga de wallpapers (espacio + gatitos),
#   script de montaje Samba con Zenity (guarda IP/usuario, pide contraseña),
#   accesos directos a Google Docs/Sheets/Slides/Drive, y configuración básica.
#
# Ejecutar como usuario normal con sudo: chmod +x setup-openbox-completo.sh && ./setup-openbox-completo.sh
set -e
USER_NAME="${SUDO_USER:-$USER}"

echo "=== Inicio del instalador Openbox completo ==="
echo "Usuario detectado: ${USER_NAME}"
sleep 1

echo "=== Actualizando paquetes del sistema ==="
sudo apt update
sudo apt full-upgrade -y

echo "=== Instalando paquetes necesarios (ligero pero funcional) ==="
sudo apt install -y \
  xorg openbox obconf lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  jgmenu nitrogen pcmanfm terminator thunar \
  network-manager network-manager-gnome nm-connection-editor \
  xfce4-power-manager volumeicon-alsa pavucontrol pulseaudio \
  lxappearance papirus-icon-theme arc-theme \
  curl wget unzip git \
  cifs-utils gvfs-backends gvfs-fuse zenity \
  firefox-esr mpv yt-dlp xclip \
  fonts-dejavu

echo "=== Habilitando servicios necesarios ==="
sudo systemctl enable NetworkManager
sudo systemctl enable lightdm

# ---------------------------------------------------------------------
# LightDM autologin (autologin pero sudo seguirá pidiendo contraseña)
# ---------------------------------------------------------------------
echo "=== Configurando LightDM para autologin del usuario ${USER_NAME} ==="
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/10-autologin.conf > /dev/null <<EOF
[Seat:*]
autologin-user=${USER_NAME}
autologin-user-timeout=0
user-session=openbox
EOF

# ---------------------------------------------------------------------
# Directorios y copias iniciales de Openbox
# ---------------------------------------------------------------------
echo "=== Preparando configuración de Openbox en ~/.config/openbox ==="
mkdir -p ~/.config/openbox
# Copiar como base los archivos del sistema (si existen)
if [ -f /etc/xdg/openbox/rc.xml ]; then
  cp -f /etc/xdg/openbox/rc.xml ~/.config/openbox/rc.xml
fi
if [ -f /etc/xdg/openbox/menu.xml ]; then
  cp -f /etc/xdg/openbox/menu.xml ~/.config/openbox/menu.xml
fi

# autostart: arranca apps con pequeños sleeps para evitar fallos en hardware viejo
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/autostart <<'AUTOSTART'
#!/bin/bash
# Autostart optimizado con sleeps mínimos para evitar que algo se inicie
# antes de que el servidor gráfico / indicadores estén listos.

# Restaurar fondo (esperar 2s para que X esté totalmente listo)
(sleep 2 && nitrogen --restore) &

# Iniciar el escritorio (pcmanfm) para manejar el escritorio y montaje de dispositivos
(sleep 1 && pcmanfm --desktop &) &

# Gestor de red (esperar 3s para que NetworkManager se levante)
(sleep 3 && nm-applet &) &

# Icono de volumen
(sleep 3 && volumeicon &) &

# Indicador de batería / power manager
(sleep 3 && xfce4-power-manager &) &

# Lanzar script de conexión Samba (intenta conectar si hay config previa)
(sleep 4 && "$HOME/conectar_samba_auto.sh" &) &

# jgmenu no necesita iniciarse explícitamente; se invoca con jgmenu_run
AUTOSTART
chmod +x ~/.config/openbox/autostart

# ---------------------------------------------------------------------
# jgmenu: iniciar configuración y tema oscuro mínimo
# ---------------------------------------------------------------------
echo "=== Configurando jgmenu (tema básico oscuro) ==="
mkdir -p ~/.config/jgmenu
# inicializar si aún no tiene config
if [ ! -f ~/.config/jgmenu/jgmenurc ]; then
  jgmenu init || true
fi
# Ajustes visuales simples (si las claves existen en jgmenurc)
sed -i 's/^color_menu_bg.*/color_menu_bg = #2b2b2b 100/' ~/.config/jgmenu/jgmenurc 2>/dev/null || true
sed -i 's/^color_menu_fg.*/color_menu_fg = #ffffff 100/' ~/.config/jgmenu/jgmenurc 2>/dev/null || true
sed -i 's/^color_sel_bg.*/color_sel_bg = #444444 100/' ~/.config/jgmenu/jgmenurc 2>/dev/null || true
sed -i 's/^color_sel_fg.*/color_sel_fg = #00ffcc 100/' ~/.config/jgmenu/jgmenurc 2>/dev/null || true

# Atajo Super+Space y botón derecho del ratón en rc.xml para abrir jgmenu
echo "=== Añadiendo atajos en rc.xml para jgmenu (Super+Space y botón derecho) ==="
if [ -f ~/.config/openbox/rc.xml ]; then
  # insertar keybind W-space si no existe
  if ! grep -q 'W-space' ~/.config/openbox/rc.xml 2>/dev/null; then
    sed -i '/<\/keyboard>/i \
  <keybind key="W-space">\
    <action name="Execute">\
      <command>jgmenu_run</command>\
    </action>\
  </keybind>' ~/.config/openbox/rc.xml
  fi

  # reemplazar handler del botón derecho para lanzar jgmenu (si existe mousebind para 3)
  if grep -q '<mousebind button="3"' ~/.config/openbox/rc.xml 2>/dev/null; then
    sed -i '/<mousebind button="3"/,/<\/mousebind>/c\
  <mousebind button="3" action="Press">\
    <action name="Execute">\
      <command>jgmenu_run</command>\
    </action>\
  </mousebind>' ~/.config/openbox/rc.xml
  else
    # si no existía, añadir antes de </mouse>
    sed -i '/<\/mouse>/i \
  <mousebind button="3" action="Press">\
    <action name="Execute">\
      <command>jgmenu_run</command>\
    </action>\
  </mousebind>' ~/.config/openbox/rc.xml
  fi
else
  # crear un rc.xml mínimo si no existe
  cat > ~/.config/openbox/rc.xml <<'RCXML'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="W-space">
      <action name="Execute">
        <command>jgmenu_run</command>
      </action>
    </keybind>
    <keybind key="W-Return">
      <action name="Execute">
        <command>terminator</command>
      </action>
    </keybind>
  </keyboard>
  <mouse>
    <mousebind button="3" action="Press">
      <action name="Execute">
        <command>jgmenu_run</command>
      </action>
    </mousebind>
  </mouse>
</openbox_config>
RCXML
fi

# ---------------------------------------------------------------------
# Wallpapers (espacio + gatitos)
# ---------------------------------------------------------------------
echo "=== Preparando wallpapers (espacio + gatitos) ==="
WPDIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WPDIR"

# Intento de descargar ZIP pre-preparado si existe (el enlace es un placeholder).
# Reemplaza la URL por tu servidor o repo con los wallpapers cuando quieras.
WALL_ZIP_URL="https://example.com/wallpapers-space-cats.zip"
TMPZIP="$WPDIR/wallpapers.zip"

# Intentar descargar; si falla, no aborta (no es crítico)
if curl -sfL "$WALL_ZIP_URL" -o "$TMPZIP"; then
  unzip -o "$TMPZIP" -d "$WPDIR"
  rm -f "$TMPZIP"
  echo "Wallpapers instalados en $WPDIR"
else
  echo "Aviso: no pude descargar wallpapers desde $WALL_ZIP_URL (placeholder)."
  echo "Puedes copiar imágenes a $WPDIR o editar el script para poner una URL válida."
fi

# Establecer un fondo (si hay imágenes)
FIRST_IMG=$(find "$WPDIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -n1 || true)
if [ -n "$FIRST_IMG" ]; then
  nitrogen --set-scaled "$FIRST_IMG" --save
fi

# ---------------------------------------------------------------------
# Scripts multimedia (mpv + yt-dlp) y utilidades del portapapeles
# ---------------------------------------------------------------------
echo "=== Creando scripts multimedia en ~/scripts ==="
mkdir -p ~/scripts

# yt (reproducir URL del portapapeles o argumento) - 480p
cat > ~/scripts/yt <<'YT_SCRIPT'
#!/usr/bin/env bash
# Reproducir YouTube (u otra URL) en mpv, limitando a 480p para equipos modestos
URL="${1:-$(xclip -o -selection clipboard 2>/dev/null)}"
if [ -z "$URL" ]; then
  echo "Uso: yt <URL>  (o copia la URL al portapapeles)"
  exit 1
fi
mpv --ytdl-format="bestvideo[height<=480]+bestaudio/best[height<=480]" "$URL"
YT_SCRIPT
chmod +x ~/scripts/yt

# platzi (misma lógica)
cat > ~/scripts/platzi <<'PL_SCRIPT'
#!/usr/bin/env bash
URL="${1:-$(xclip -o -selection clipboard 2>/dev/null)}"
if [ -z "$URL" ]; then
  echo "Uso: platzi <URL>  (o copia la URL al portapapeles)"
  exit 1
fi
mpv --ytdl-format="bestvideo[height<=480]+bestaudio/best[height<=480]" "$URL"
PL_SCRIPT
chmod +x ~/scripts/platzi

# mp3 (descargar audio a ~/Music y notificar)
mkdir -p ~/Music
cat > ~/scripts/mp3 <<'MP3_SCRIPT'
#!/usr/bin/env bash
URL="$(xclip -o -selection clipboard 2>/dev/null)"
if [ -z "$URL" ]; then
  zenity --error --title="MP3" --text="No hay URL en el portapapeles."
  exit 1
fi
OUTPUT=$(yt-dlp -x --audio-format mp3 -o "$HOME/Music/%(title)s.%(ext)s" "$URL" --print filename 2>/dev/null)
FNAME=$(basename "$OUTPUT")
notify-send -i audio-x-generic "Descarga MP3" "Archivo: $FNAME"
MP3_SCRIPT
chmod +x ~/scripts/mp3

# Añadir al PATH del usuario local (opcional, para poder ejecutar 'yt' directamente)
if ! grep -q 'export PATH="$HOME/scripts:$PATH"' ~/.profile 2>/dev/null; then
  echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.profile
fi

# ---------------------------------------------------------------------
# Script de conexión Samba (guarda IP/usuario/carpetas; pide contraseña cada vez)
# ---------------------------------------------------------------------
echo "=== Creando ~/conectar_samba_auto.sh (Zenity, recuerda IP/usuario, pide password) ==="
cat > ~/conectar_samba_auto.sh <<'SAMBA'
#!/usr/bin/env bash
CONFIG="$HOME/.samba_conexion.conf"
MOUNT_DIR="$HOME/samba_compartida"
mkdir -p "$MOUNT_DIR"

# Cargar config (si existe)
if [ -f "$CONFIG" ]; then
  source "$CONFIG"
fi

# Pedir datos si no están en config
if [ -z "$IP" ]; then
  IP=$(zenity --entry --title="Conectar a Carpeta Samba" --text="IP del servidor:")
fi
if [ -z "$CARPETA" ]; then
  CARPETA=$(zenity --entry --title="Conectar a Carpeta Samba" --text="Nombre de la carpeta compartida:")
fi
if [ -z "$USUARIO" ]; then
  USUARIO=$(zenity --entry --title="Conectar a Carpeta Samba" --text="Usuario Samba:")
fi

# Guardar config (sin contraseña)
cat > "$CONFIG" <<EOF
IP="$IP"
CARPETA="$CARPETA"
USUARIO="$USUARIO"
EOF
chmod 600 "$CONFIG"

# Pedir contraseña cada vez
PASS=$(zenity --password --title="Conectar a Carpeta Samba")
[ -z "$PASS" ] && exit 1

# Desmontar si ya montado
if mountpoint -q "$MOUNT_DIR"; then
  sudo umount "$MOUNT_DIR"
fi

# Montar con cifs
sudo mount -t cifs "//$IP/$CARPETA" "$MOUNT_DIR" \
  -o username="$USUARIO",password="$PASS",iocharset=utf8,vers=3.0

if [ $? -eq 0 ]; then
  zenity --info --title="Conexión Samba" --text="Carpeta montada en:\n$MOUNT_DIR"
else
  zenity --error --title="Conexión Samba" --text="No se pudo montar //${IP}/${CARPETA}"
fi
SAMBA
chmod +x ~/conectar_samba_auto.sh

# ---------------------------------------------------------------------
# Accesos directos a Google Docs / Sheets / Slides / Drive (archivos .desktop)
# ---------------------------------------------------------------------
echo "=== Creando accesos directos a Google Office en ~/.local/share/applications/google-office ==="
mkdir -p ~/.local/share/applications/google-office

cat > ~/.local/share/applications/google-office/google-docs.desktop <<'GDocs'
[Desktop Entry]
Name=Google Docs
Comment=Google Docs - Documentos en línea
Exec=firefox --new-window https://docs.google.com/document/
Terminal=false
Type=Application
Icon=google-docs
Categories=Network;Office;
GDocs

cat > ~/.local/share/applications/google-office/google-sheets.desktop <<'GSheets'
[Desktop Entry]
Name=Google Sheets
Comment=Google Sheets - Hojas de cálculo en línea
Exec=firefox --new-window https://docs.google.com/spreadsheets/
Terminal=false
Type=Application
Icon=google-sheets
Categories=Network;Office;
GSheets

cat > ~/.local/share/applications/google-office/google-slides.desktop <<'GSlides'
[Desktop Entry]
Name=Google Slides
Comment=Google Slides - Presentaciones en línea
Exec=firefox --new-window https://docs.google.com/presentation/
Terminal=false
Type=Application
Icon=google-slides
Categories=Network;Office;
GSlides

cat > ~/.local/share/applications/google-office/google-drive.desktop <<'GDrive'
[Desktop Entry]
Name=Google Drive
Comment=Google Drive - Almacenamiento en la nube
Exec=firefox --new-window https://drive.google.com/drive/my-drive
Terminal=false
Type=Application
Icon=google-drive
Categories=Network;Office;
GDrive

# actualizar la base de datos de desktop (no crítico si falla)
update-desktop-database ~/.local/share/applications 2>/dev/null || true

# ---------------------------------------------------------------------
# lxappearance y Papirus: sugerencia de tema (no forzamos demasiado)
# ---------------------------------------------------------------------
echo "=== Configuración mínima GTK: tema oscuro y Papirus icons (puedes ajustar con lxappearance) ==="
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini <<'GTKCFG'
[Settings]
gtk-theme-name = Arc-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Sans 10
GTKCFG

# ---------------------------------------------------------------------
# Mensaje final y recordatorios
# ---------------------------------------------------------------------
echo
echo "=== Instalación y configuración completadas ==="
echo "Recomendaciones finales:"
echo " - Reinicia el equipo: sudo reboot"
echo " - Cuando inicies verás LightDM y entrará automáticamente en Openbox."
echo " - Para usar los scripts multimedia: copia la URL y presiona Super+Space para abrir jgmenu (o ejecuta ~/scripts/yt)."
echo " - Para conectar Samba: el script ~/conectar_samba_auto.sh preguntará la contraseña y recordará IP/usuario."
echo " - Abre lxappearance para ajustar tema/íconos si quieres otros."
echo
echo "Notas:"
echo " - Si el script descargador de wallpapers no funcionó, reemplaza WALL_ZIP_URL por una URL válida dentro del script o copia manualmente imágenes a ~/Pictures/Wallpapers"
echo " - El autologin está activado (no pedirá contraseña al iniciar). Para tareas administrativas se seguirá solicitando la contraseña con sudo."
echo
echo "Listo — disfruta tu ricing ligero con Openbox. Si quieres, puedo pasar un único comando curl|bash que descargue este script y lo ejecute en una línea."
