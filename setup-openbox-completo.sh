#!/bin/bash
set -e

echo "=== Actualizando sistema ==="
sudo apt update && sudo apt full-upgrade -y

echo "=== Instalando paquetes básicos ==="
sudo apt install -y openbox nitrogen pcmanfm terminator \
  network-manager network-manager-gnome volumeicon-alsa xfce4-power-manager \
  lightdm lightdm-gtk-greeter jgmenu curl unzip lxappearance papirus-icon-theme \
  cifs-utils gvfs-backends gvfs-fuse zenity firefox-esr mpv youtube-dl

echo "=== Configurando LightDM para autologin ==="
sudo mkdir -p /etc/lightdm/lightdm.conf.d
echo "[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
user-session=openbox
" | sudo tee /etc/lightdm/lightdm.conf.d/10-autologin.conf

echo "=== Configurando Openbox ==="
mkdir -p ~/.config/openbox
cp /etc/xdg/openbox/{rc.xml,menu.xml,autostart} ~/.config/openbox/

cat > ~/.config/openbox/autostart <<EOF
nitrogen --set-scaled --random ~/Pictures/Wallpapers &
pcmanfm --desktop &
nm-applet &
volumeicon &
xfce4-power-manager &
~/conectar_samba_auto.sh &
EOF

mkdir -p ~/Pictures/Wallpapers
echo "Descargando wallpapers de espacio y gatitos..."
curl -L -o ~/Pictures/Wallpapers/wallpapers.zip "https://tu-servidor.com/wallpapers.zip"
unzip -o ~/Pictures/Wallpapers/wallpapers.zip -d ~/Pictures/Wallpapers/
rm ~/Pictures/Wallpapers/wallpapers.zip

echo "=== Configuración jgmenu (tema oscuro) ==="
mkdir -p ~/.config/jgmenu
jgmenu init
sed -i 's/color_menu_bg.*/color_menu_bg = #2b2b2b 100/' ~/.config/jgmenu/jgmenurc
sed -i 's/color_menu_fg.*/color_menu_fg = #ffffff 100/' ~/.config/jgmenu/jgmenurc
sed -i 's/color_sel_bg.*/color_sel_bg = #444444 100/' ~/.config/jgmenu/jgmenurc
sed -i 's/color_sel_fg.*/color_sel_fg = #00ffcc 100/' ~/.config/jgmenu/jgmenurc

sed -i '/<mousebind button="3"/,/<\/mousebind>/c\
  <mousebind button="3" action="Press">\
    <action name="Execute">\
      <command>jgmenu_run</command>\
    </action>\
  </mousebind>' ~/.config/openbox/rc.xml

sed -i '/<keyboard>/a \
  <keybind key="W-space">\
    <action name="Execute">\
      <command>jgmenu_run</command>\
    </action>\
  </keybind>' ~/.config/openbox/rc.xml

echo "=== Creando script para conexión Samba con Zenity ==="
cat > ~/conectar_samba_auto.sh <<'EOL'
#!/bin/bash

CONFIG="$HOME/.samba_conexion.conf"
MOUNT_DIR="$HOME/samba_compartida"
mkdir -p "$MOUNT_DIR"

if [ -f "$CONFIG" ]; then
    source "$CONFIG"
fi

if [ -z "$IP" ]; then
    IP=$(zenity --entry --title="Conectar a Carpeta Samba" --text="IP del servidor:")
fi

if [ -z "$CARPETA" ]; then
    CARPETA=$(zenity --entry --title="Conectar a Carpeta Samba" --text="Nombre de la carpeta compartida:")
fi

if [ -z "$USUARIO" ]; then
    USUARIO=$(zenity --entry --title="Conectar a Carpeta Samba" --text="Usuario Samba:")
fi

cat > "$CONFIG" <<EOF
IP="$IP"
CARPETA="$CARPETA"
USUARIO="$USUARIO"
EOF

PASS=$(zenity --password --title="Conectar a Carpeta Samba")
[ -z "$PASS" ] && exit 1

mountpoint -q "$MOUNT_DIR" && sudo umount "$MOUNT_DIR"

sudo mount -t cifs "//$IP/$CARPETA" "$MOUNT_DIR" \
  -o username="$USUARIO",password="$PASS",iocharset=utf8,vers=3.0

if [ $? -eq 0 ]; then
    zenity --info --title="Conexión Exitosa" --text="Carpeta montada en:\n$MOUNT_DIR"
else
    zenity --error --title="Error" --text="No se pudo montar la carpeta."
fi
EOL
chmod +x ~/conectar_samba_auto.sh

echo "=== Creando accesos directos para Google Office en jgmenu ==="
mkdir -p ~/.local/share/applications/google-office

cat > ~/.local/share/applications/google-office/google-docs.desktop <<EOF
[Desktop Entry]
Name=Google Docs
Comment=Google Docs - Documentos en línea
Exec=firefox --new-window https://docs.google.com/document/
Terminal=false
Type=Application
Icon=google-docs
Categories=Network;Office;
EOF

cat > ~/.local/share/applications/google-office/google-sheets.desktop <<EOF
[Desktop Entry]
Name=Google Sheets
Comment=Google Sheets - Hojas de cálculo en línea
Exec=firefox --new-window https://docs.google.com/spreadsheets/
Terminal=false
Type=Application
Icon=google-sheets
Categories=Network;Office;
EOF

cat > ~/.local/share/applications/google-office/google-slides.desktop <<EOF
[Desktop Entry]
Name=Google Slides
Comment=Google Slides - Presentaciones en línea
Exec=firefox --new-window https://docs.google.com/presentation/
Terminal=false
Type=Application
Icon=google-slides
Categories=Network;Office;
EOF

cat > ~/.local/share/applications/google-office/google-drive.desktop <<EOF
[Desktop Entry]
Name=Google Drive
Comment=Google Drive - Almacenamiento en la nube
Exec=firefox --new-window https://drive.google.com/drive/my-drive
Terminal=false
Type=Application
Icon=google-drive
Categories=Network;Office;
EOF

echo "=== Configuración completada. Reinicia para iniciar Openbox y disfrutar tu setup ==="


