#!/usr/bin/env bash
#
# instalar.sh — Instalador LaCasita Free
# Destritos: /etc/VPS-MX + marcações em /usr/local + serviço systemd do vpsmx-server.py
#
# Uso:
#   bash instalar.sh                -> usa ZIP_URL abaixo
#   bash instalar.sh <URL-do-zip>   -> usa a URL passada na linha de comando
#   bash instalar.sh --local        -> usa ./lacasita-free.zip do diretório atual
#

set -u

# ============================== CONFIG =================================

# Troque pela URL real onde você subir o arquivo (Dropbox/GitHub/raw/etc).
# Lembre: para o Dropbox funcionar direto no curl/wget, o link precisa
# terminar com ?dl=raw ou ?dl=1  (ex.: https://...?dl=1)
ZIP_URL="https://example.com/lacasita-free.zip"

PROJ="/etc/VPS-MX"
SRV_PY="$PROJ/vpsmx-server.py"
SRV_PORT="4444"
ZIP_TMP="/tmp/lacasita-free.zip"

# ========================== PALETA (estilo menu) =======================

VERM='\e[1;31m'
VERD='\e[1;32m'
AMA='\e[1;33m'
AZU='\e[1;34m'
MAG='\e[1;35m'
BRA='\e[1;37m'
GRA='\e[1;90m'
RST='\e[0m'

bar()  { echo -e "${GRA}————————————————————————————————————————————————————${RST}"; }
ok()   { echo -e "${VERD}[✓]${RST} ${BRA}$*${RST}"; }
warn() { echo -e "${AMA}[!]${RST}  $*"; }
err()  { echo -e "${VERM}[✗]${RST} ${VERM}$*${RST}"; }
step() { echo -e "${AZU}➤${RST} ${BRA}$*${RST}"; }

# ============================== PRE-CHECAGEM ===========================

[[ "$(id -u)" != "0" ]] && {
  echo -e "${VERM}————————————————————————————————————————————————————${RST}"
  echo -e "${VERM}| ${BRA}RODE COMO ROOT${RST} ${VERM}/ ${BRA}sudo bash instalar.sh${RST} ${VERM}|${RST}"
  echo -e "${VERM}————————————————————————————————————————————————————${RST}"
  exit 1
}

clear
bar
echo -e "${BRA}        ❯❯❯❯❯❯ ꧑꧑  ꜱᴄʀɪᴩᴛ ᴍᴏᴅ ʟᴀᴄᴀꜱɪᴛᴀꜰʀᴇᴇ ꧑꧑ ❮❮❮❯❯${RST}"
echo -e "${BRA}          ${AMA}I N S T A L A D O R   A U T O M Á T I C O${RST}"
bar

# ========================= DEPENDENCIAS DO SISTEMA =====================

step "Verificando dependências do sistema"
DEPS=(python3 curl wget unzip ncurses-bin perl lsof bc less)
MISSING=()
for p in "${DEPS[@]}"; do
    command -v "$p" >/dev/null 2>&1 || MISSING+=( "$p" )
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${AMA}   -> instalando pacotes: ${BRA}${MISSING[*]}${RST}"
    command -v apt-get >/dev/null 2>&1 || { err "Sem apt-get; instale manualmente: ${MISSING[*]}"; exit 1; }
    apt-get update -qq   &> /dev/null
    apt-get install -y -qq "${MISSING[@]}" &> /dev/null || { err "Falha ao instalar: ${MISSING[*]}"; exit 1; }
fi
ok "Dependências resolvidas: ${DEPS[*]}"

# ============================== DIRETORIOS =============================

step "Criando estrutura de diretórios"
mkdir -p "$PROJ"
# Marcações que o menu verifica silenciosamente
mkdir -p /usr/local/include/snaps
mkdir -p /usr/local/lib/sped
mkdir -p /usr/local/lib/sped/tools
mkdir -p /usr/local/lib/rm
mkdir -p /usr/local/libreria
mkdir -p /usr/local/megat
ok "Diretórios criados ( /etc/VPS-MX + marcas em /usr/local )"

# ========================= PEGAR O PACOTE ZIP ==========================

step "Obtendo o pacote lacasita-free.zip"

if [[ $# -ge 1 && "$1" != "--local" ]]; then
    ZIP_URL="$1"
elif [[ $# -ge 1 && "$1" == "--local" ]]; then
    if [[ ! -f ./lacasita-free.zip ]]; then
        err "Modo --local, mas ./lacasita-free.zip não existe no diretório atual."
        exit 1
    fi
    cp -f ./lacasita-free.zip "$ZIP_TMP"
fi

# Se ZIP_URL é 'example.com' e não passou --local, tenta arquivo local
if [[ "$ZIP_URL" == *"example.com"* && -f ./lacasita-free.zip ]]; then
    warn "ZIP_URL ainda é placeholder. Usando ./lacasita-free.zip local."
    cp -f ./lacasita-free.zip "$ZIP_TMP"
elif [[ "$ZIP_URL" != *"example.com"* ]]; then
    echo -e "${GRA}   -> baixando de: ${BRA}$ZIP_URL${RST}"
    curl -fsSL "$ZIP_URL" -o "$ZIP_TMP" || {
        err "Falha ao baixar o ZIP de: $ZIP_URL"
        exit 1
    }
fi

[[ -f "$ZIP_TMP" ]] || { err "Pacote não encontrado em: $ZIP_TMP"; exit 1; }
ok "Pacote obtido: $(du -h "$ZIP_TMP" | cut -f1)"

# ==================== EXTRAIR DENTRO DE /etc/VPS-MX ====================

step "Limpando e extraindo em $PROJ"
[[ -d "$PROJ" ]] && find "$PROJ" -mindepth 1 -maxdepth 1 -exec rm -rf {} \; 2>/dev/null
mkdir -p "$PROJ"

cd "$PROJ" || exit 1
unzip -o -q "$ZIP_TMP" || { err "Falha ao extrair o zip."; exit 1; }
ok "Pacote extraído em $PROJ ( $(ls -1 | wc -l) itens )"

# ====================== PERMISSÕES + ARQUIVOS =========================

step "Configurando permissões e arquivos de metadata"
chmod +x "$PROJ/menu" 2>/dev/null
chmod +x "$SRV_PY" 2>/dev/null
[[ -f /etc/versin_script ]]     || echo 1 > /etc/versin_script
[[ -f /etc/versin_script_new ]] || echo 1 > /etc/versin_script_new
ok "Permissões e metadata prontas"

# ===================== ATALHO: /usr/bin/menu ===========================

step "Criando atalho /usr/bin/menu"
ln -sf "$PROJ/menu" /usr/bin/menu
ln -sf "$PROJ/menu" /usr/bin/VPS-MX 2>/dev/null || true
ok "Atalhos ativos: menu  |  VPS-MX"

# =================== SERVIÇO SYSTEMD DO vpsmx-server ==================

step "Instalando serviço systemd: vpsmx-server.service"
cat > /etc/systemd/system/vpsmx-server.service <<EOF
[Unit]
Description=LaCasita Free - Servidor local de key (vpsmx.txt)
Documentation=https://127.0.0.1:4444/vpsmx.txt
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $SRV_PY
WorkingDirectory=$PROJ
Restart=always
RestartSec=3
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable  vpsmx-server.service  &> /dev/null
systemctl restart vpsmx-server.service
ok "Serviço vpsmx-server.service ativado"

# =========================== VALIDACAO ================================

step "Validando o servidor local na porta $SRV_PORT"
sleep 1
for i in 1 2 3; do
    if curl -s --max-time 3 "http://127.0.0.1:$SRV_PORT/vpsmx.txt" | grep -q '127'; then
        ok "Servidor local OK -> http://127.0.0.1:$SRV_PORT/vpsmx.txt"
        break
    fi
    [[ $i == 3 ]] && { warn "Servidor demorou: veja com  systemctl status vpsmx-server"; break; }
    sleep 1
done

systemctl is-active --quiet vpsmx-server.service \
  && ok "systemd: vpsmx-server.service ativo" \
  || warn "systemd precisa de revisão: systemctl status vpsmx-server"

# ============================== FIM ====================================

bar
echo -e "${BRA}         ${VERD}I N S T A L A Ç Ã O   C O N C L U Í D A${RST}"
bar
echo
echo -e "${BRA} ${VERD}»${RST} ${BRA}Painel   :${RST} ${BRA}/etc/VPS-MX/menu${RST}"
echo -e "${BRA} ${VERD}»${RST} ${BRA}Atalho   :${RST} ${BRA}menu${RST}"
echo -e "${BRA} ${VERD}»${RST} ${BRA}Serviço  :${RST} ${BRA}systemctl status vpsmx-server${RST}"
echo -e "${BRA} ${VERD}»${RST} ${BRA}Log      :${RST} ${BRA}journalctl -u vpsmx-server -f${RST}"
bar
echo
echo -e "  \e[1;93m[\e[1;92m1\e[1;93m]\e[0m \e[1;93mDigite \e[1;92mmenu \e[1;37mpara abrir o \e[1;92mGerenciador SSH\e[0m"
echo
echo -ne "  ${GRA}Pressione ENTER para finalizar...${RST}"
read -r
echo -e "${RST}"
exit 0
