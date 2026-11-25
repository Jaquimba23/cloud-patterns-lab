#!/usr/bin/env bash
# Ejecutar en CloudShell, dentro de 06-bastion, después de terraform apply.
set -u
BASTION=$(terraform output -raw bastion_ip)
PRIVATE=$(terraform output -raw private_ip)
KEY=~/lab-key
CFG=~/bastion-ssh-config

cat > "$CFG" <<EOT
Host bastion
  HostName $BASTION
  User ec2-user
  IdentityFile $KEY
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR

Host privado
  HostName $PRIVATE
  User ec2-user
  IdentityFile $KEY
  ProxyJump bastion
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
EOT

echo "Bastion (IP publica): $BASTION"
echo "Servidor privado (IP privada): $PRIVATE"

echo
echo "=== 1. SSH DIRECTO al servidor privado (debe fallar) ==="
if ssh -F /dev/null -i "$KEY" -o ConnectTimeout=6 -o StrictHostKeyChecking=no -o BatchMode=yes ec2-user@"$PRIVATE" hostname 2>/dev/null; then
  echo "ERROR: el servidor privado es accesible directamente"
else
  echo "BLOQUEADO: no hay ruta directa al servidor privado (sin IP publica)"
fi

echo
echo "=== 2. SSH al BASTION ==="
ssh -F "$CFG" bastion 'echo "Conectado a: $(hostname)"; echo "IP privada: $(hostname -I)"'

echo
echo "=== 3. SSH al servidor privado A TRAVES del bastion (ProxyJump) ==="
ssh -F "$CFG" privado 'echo "Conectado a: $(hostname)"; echo "IP privada: $(hostname -I)"; echo "Usuario: $(whoami)"'
