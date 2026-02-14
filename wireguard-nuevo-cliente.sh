#!/bin/bash

#VARIABLES
fecha2="$(date +%Y%m%d-%H%M)"
ARCHIVO="/etc/wireguard/wg0.conf"
ARCHIVO_TMP="/tmp/$fecha2-wireguard.conf"
Interfaz=$(ip -4 route show default | awk '/^default/ {print $5}')
InterfazIP=$(ip -4 addr show dev "$Interfaz" | \
                   awk '/inet / && !/127\./ && !/169\.254\./ { 
                       split($2, a, "/"); 
                       print a[1]; 
                       exit 
                   }')
ServerPublicKey=$(cat /etc/wireguard/servidor-keys/publickey)
DNS_SERVERS="1.1.1.1"

# solicitar nombre usuario remoto
echo "Escriba el nombre del nuevo usuario sin espacios ni caracteres especiales"
read nombreCliente
# echo $nombreCliente

# Configuracion usuario
mkdir -p /etc/wireguard/$nombreCliente
cd /etc/wireguard/$nombreCliente
wg genkey | tee privatekey | wg pubkey > publickey
UserPrivateKey=$(cat /etc/wireguard/$nombreCliente/privatekey)
UserPublicKey=$(cat /etc/wireguard/$nombreCliente/publickey)

sleep 1

# calcular nueva IP
ultimaIP=$(cat /root/scripts/wireguard-ip-clientes.txt)
echo $ultimaIP

sleep 1

nuevaIP=$(echo $ultimaIP+1 | bc)


usuarioIP="10.10.2."$nuevaIP
echo $usuarioIP

# actualiza archivo de IPs
echo $nuevaIP > /root/scripts/wireguard-ip-clientes.txt

sleep 1

echo "" >> $ARCHIVO
echo "[Peer]" >> $ARCHIVO
echo "PublicKey = $UserPublicKey" >> $ARCHIVO
echo "AllowedIPs = $usuarioIP/32" >> $ARCHIVO
echo "PersistentKeepalive = 25" >> $ARCHIVO
echo "" >> $ARCHIVO

echo "Información para configurar su cliente"
echo "Llave privada: 	$UserPrivateKey" 
echo "Llave pública: 	$UserPublicKey"
echo "Su IP de VPN:		$usuarioIP/32"
echo "---------------------------------"
echo "Datos del Servidor"
echo "Llave pública $ServerPublicKey"
echo "Puerto:			61820"
echo "IP/Dominio:		$InterfazIP"

wg-quick down wg0
wg-quick up wg0

# genera QR
ARCHIVO_TMP="/tmp/$fecha2-$nombreCliente-wireguard.conf"
DNS_SERVERS="1.1.1.1"
cat > "$ARCHIVO_TMP" << EOF
# ${nombreCliente} - $(date)
[Interface]
PrivateKey = ${UserPrivateKey}
Address = ${usuarioIP}
DNS = ${DNS_SERVERS}

[Peer]
PublicKey = ${ServerPublicKey}
Endpoint = ${InterfazIP}:61820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# genera QR
qrencode -t ansiutf8 -r "$ARCHIVO_TMP"

# info administrador para localizar archivo configuración para cliente
echo “Archivo de configuración para el cliente $nombreCliente”
echo $ARCHIVO_TMP
