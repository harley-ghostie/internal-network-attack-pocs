#!/bin/bash

# Faixa de rede interna autorizada para varredura SMB.
# Substitua pelo range liberado no escopo do teste.
# Exemplo: "10.10.10.0/24"
RANGE="10.50.103.0/24"

# Arquivo onde serão salvos os hosts com SMB signing desativado,
# no formato esperado pelo ntlmrelayx.py.
TARGETS_FILE="/tmp/relay_targets.txt"

echo "[+] Escaneando rede $RANGE com crackmapexec..."
crackmapexec smb $RANGE | grep "Signing: False" | cut -d " " -f 1 | sort -u | while read ip; do
    echo "smb://$ip"
done > "$TARGETS_FILE"

echo "[+] Arquivo de alvos criado em: $TARGETS_FILE"
echo
cat "$TARGETS_FILE"
echo
echo "[+] Pronto pra rodar com ntlmrelayx 😈"
