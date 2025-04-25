#!/usr/bin/env bash

# Script para montar driver 
VERSION="1.0"
AUTHOR="Luiz Paulo Nievola"
# Data: 06-04-2025

# Cores para o menu
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuração de segurança
#set -o errexit
set -o nounset
set -o pipefail

# Diretórios importantes
MOUNT_DIR="$HOME/Cloud/"
LOG_DIR="$HOME/.cache/rclone/logs/"
CACHE_DIR="$HOME/.cache/rclone/vfs/"
CONFIG_DIR="$HOME/.config/rclone/"

# Criar diretórios se não existirem
mkdir -p "$MOUNT_DIR" "$LOG_DIR" "$CACHE_DIR" "$CONFIG_DIR"

# Flags padrão para o comando `rclone mount`
RCLONE_FLAGS=(
    "--vfs-cache-mode=full"
    "--vfs-cache-max-age=3d"
    "--vfs-read-ahead=250M"
    "--buffer-size=512M"
    "--dir-cache-time=72h"
    "--poll-interval=100s"
    "--attr-timeout=5s"
    "--use-mmap"
    "--log-file=$LOG_DIR/rclone-$(date +%Y%m%d).log"
    "--log-level=ERROR"
)

# Flags comuns reutilizáveis
COMMON_FLAGS="--vfs-read-chunk-size=64M --transfers=4 --log-level=ERROR"
CACHE_FLAGS="--vfs-cache-max-size=250M --vfs-cache-max-age=3d"

# Flags personalizadas para cada remote
declare -A REMOTE_FLAGS
REMOTE_FLAGS[oracle_vm]="--rc --bwlimit=5M:5M --vfs-cache-max-size=1G --vfs-cache-max-age=7d --use-server-modtime --vfs-read-ahead=64M"
REMOTE_FLAGS[Drive]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"
REMOTE_FLAGS[OneDrive]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"
REMOTE_FLAGS[Dropbox]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"
REMOTE_FLAGS[pCloud]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"
REMOTE_FLAGS[Mega]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"
REMOTE_FLAGS[Yandex]="--bwlimit=1M:1M $CACHE_FLAGS --vfs-read-ahead=32M"

# Menu principal
MENU=(
    "${GREEN} 1) Verificar e instalar o rclone${NC}"
    "${GREEN} 2) Verificar e atualizar o rclone${NC}"
    "${YELLOW} 3) Verificar pasta para montagem${NC}"
    "${BLUE} 4) Montar driver individual${NC}"
    "${RED} 5) Desmontar driver individual${NC}"
    "${BLUE} 6) Montar todos os drivers${NC}"
    "${RED} 7) Desmontar todos os drivers${NC}"
    "${CYAN} 8) Mostrar uso do cache${NC}"
    "${MAGENTA} 9) Visualizar logs${NC}"
    "${WHITE}10) Configurações avançadas${NC}"
    "${RED}11) Sair${NC}"
)

# Funções ----------------------------------------------------------------------

show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ ${CYAN}▓▓▓  Gerenciador Rclone Shell v${VERSION}  ▓▓▓${BLUE}          ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║ ${YELLOW}Autor: ${AUTHOR}${BLUE}                             ║${NC}"
    echo -e "${BLUE}║ ${YELLOW}Data: $(date +"%d/%m/%Y %H:%M") ${BLUE}                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}\n"
}

install_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${GREEN}>>> Instalando o Rclone...${NC}"
        sudo -v && curl https://rclone.org/install.sh | sudo bash
        echo -e "${GREEN}✓ Rclone instalado com sucesso!${NC}"
    else
        echo -e "${YELLOW}ℹ Rclone já está instalado.${NC}"
    fi
}

update_rclone() {
    local current_version latest_version
    current_version=$(rclone --version | head -n1 | awk '{print $2}')
    latest_version=$(curl -fsS https://downloads.rclone.org/version.txt | awk '{print $2}')

    if [[ "$current_version" != "$latest_version" ]]; then
        echo -e "${GREEN}>>> Atualizando Rclone para v$latest_version...${NC}"
        sudo rclone selfupdate --stable
        echo -e "${GREEN}✓ Atualização concluída!${NC}"
    else
        echo -e "${YELLOW}ℹ Você já tem a versão mais recente (v$current_version).${NC}"
    fi
}

setup_mount_directory() {
    [[ -d ${MOUNT_DIR} ]] && echo -e "${YELLOW}ℹ Diretório de montagem já existe.${NC}" || {
        echo -e "${GREEN}>>> Criando diretório em ${MOUNT_DIR}...${NC}"
        mkdir -p "${MOUNT_DIR}"
    }

    for remote in $(rclone listremotes); do
        remote_clean="${remote%:}"
        if [[ ! -d "${MOUNT_DIR}${remote_clean}" ]]; then
            echo -e "${GREEN}>>> Criando subdiretório para ${remote_clean}...${NC}"
            mkdir -p "${MOUNT_DIR}${remote_clean}"
        else
            echo -e "${YELLOW}ℹ Subdiretório para ${remote_clean} já existe.${NC}"
        fi
    done
}

mount_all_remotes() {
    for remote in $(rclone listremotes); do
        remote_clean="${remote%:}"
        mount_point="${MOUNT_DIR}${remote_clean}"
        mkdir -p "$mount_point"

        echo -e "${BLUE}>>> Montando $remote_clean...${NC}"
        flags=( "${RCLONE_FLAGS[@]}" )
        [[ -n "${REMOTE_FLAGS[$remote_clean]:-}" ]] && flags+=( ${REMOTE_FLAGS[$remote_clean]} )

        # Mesmo padrão do mount_single_remote:
        rclone mount "$remote" "$mount_point" "${flags[@]}" &
        echo -e "${GREEN}✓ $remote_clean montado com sucesso!${NC}"
    done
}

unmount_all_remotes() {
    if [[ -z $(mount | grep "${MOUNT_DIR}") ]]; then
        echo "ℹ Nenhum remote está montado."
        return
    fi

    for remote in $(rclone listremotes); do
        remote_clean="${remote%:}"
        mp="${MOUNT_DIR}${remote_clean}"
        if mountpoint -q "${mp}"; then
            echo ">>> Desmontando $remote_clean…"
            # tenta fusermount, com fallback
            if ! fusermount -uz "${mp}"; then
                umount -l "${mp}" || true
            fi
            # ignora erro caso não haja RC
            rclone rc vfs/forget dir="${mp}" &>/dev/null || true
        fi
    done

    echo "✓ Todos os remotes foram desmontados."
}

mount_single_remote() {
    local remotes=($(rclone listremotes))

    echo -e "\n${BLUE}REMOTES DISPONÍVEIS:${NC}"
    select remote in "${remotes[@]}" "Voltar"; do
        [[ "$remote" == "Voltar" ]] && break

        if [[ -n "$remote" ]]; then
            remote_clean="${remote%:}"
            echo -e "${BLUE}>>> Montando $remote_clean...${NC}"
            flags=( "${RCLONE_FLAGS[@]}" )
            [[ -n "${REMOTE_FLAGS[$remote_clean]:-}" ]] && flags+=( ${REMOTE_FLAGS[$remote_clean]} )

            rclone mount "$remote" "${MOUNT_DIR}${remote_clean}" "${flags[@]}" &
            echo -e "${GREEN}✓ $remote_clean montado com sucesso!${NC}"
            break
        else
            echo -e "${RED}⚠ Opção inválida!${NC}"
        fi
    done
}

unmount_single_remote() {
    local remotes=($(rclone listremotes))

    echo -e "\n${RED}REMOTES MONTADOS:${NC}"
    select remote in "${remotes[@]}" "Voltar"; do
        [[ "$remote" == "Voltar" ]] && break

        if [[ -n "$remote" ]]; then
            remote_clean="${remote%:}"
            if mountpoint -q "${MOUNT_DIR}${remote_clean}"; then
                echo -e "${RED}>>> Desmontando $remote_clean...${NC}"
                fusermount -uz "${MOUNT_DIR}${remote_clean}"
                echo -e "${GREEN}✓ $remote_clean desmontado!${NC}"
            else
                echo -e "${YELLOW}ℹ $remote_clean não está montado.${NC}"
            fi
            break
        else
            echo -e "${RED}⚠ Opção inválida!${NC}"
        fi
    done
}

show_cache_usage() {
    [[ -d "$CACHE_DIR" ]] || {
        echo -e "${RED}⚠ Diretório de cache não encontrado!${NC}"
        return
    }

    echo -e "\n${CYAN}=== USO DO CACHE ===${NC}"
    echo -e "${YELLOW}Local: $CACHE_DIR${NC}"

    echo -e "\n${GREEN}TOTAL:${NC}"
    du -sh "$CACHE_DIR" 2>/dev/null || echo -e "${RED}Erro ao ler cache${NC}"

    echo -e "\n${BLUE}POR REMOTE:${NC}"
    for remote_dir in "$CACHE_DIR"/*; do
        [[ -d "$remote_dir" ]] || continue
        remote_name=$(basename "$remote_dir")
        size=$(du -sh "$remote_dir" | awk '{print $1}')
        echo -e "${MAGENTA}● ${remote_name}:${NC} ${size}"
    done
}

show_rclone_logs() {
    # Garantir que o diretório de logs existe
    mkdir -p "$LOG_DIR"

    local log_file=$(ls -t "$LOG_DIR" | grep "rclone.*log" | head -n1)

    if [[ -z "$log_file" ]]; then
        echo -e "${YELLOW}ℹ Nenhum arquivo de log encontrado.${NC}"
        echo -e "${BLUE}▶ Criando novo arquivo de log...${NC}"
        log_file="rclone-$(date +%Y%m%d-%H%M%S).log"
        touch "$LOG_DIR/$log_file"
        echo -e "${GREEN}✓ Novo log criado: $log_file${NC}"
        echo -e "${YELLOW}ℹ Execute alguma operação para gerar registros.${NC}"
        return
    fi

    echo -e "\n${CYAN}=== ÚLTIMOS LOGS ===${NC}"
    echo -e "${YELLOW}Arquivo: ${LOG_DIR}${log_file}${NC}\n"

    if [[ ! -s "${LOG_DIR}${log_file}" ]]; then
        echo -e "${YELLOW}ℹ O arquivo de log está vazio.${NC}"
        echo -e "${BLUE}▶ Execute alguma operação para gerar registros.${NC}"
        return
    fi

    # Mostra logs coloridos
    tail -n 20 "${LOG_DIR}${log_file}" | while read -r line; do
        if [[ "$line" == *"ERROR"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"WARN"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"INFO"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" == *"DEBUG"* ]]; then
            echo -e "${BLUE}$line${NC}"
        else
            echo -e "$line"
        fi
    done

    echo -e "\n${CYAN}Pressione:${NC}"
    echo -e "▶ ${GREEN}Enter${NC} para ver o log completo"
    echo -e "▶ ${RED}Q${NC} para voltar ao menu"

    # Usando read com timeout e tratamento especial para 'q'
    while true; do
        read -n1 -s -t 5 input  # Timeout de 5 segundos
        case $input in
            q|Q) break ;;
            "") less -R "${LOG_DIR}${log_file}"; break ;;
            *) : ;;  # Ignora outras teclas
        esac
    done
}

advanced_settings() {
    echo -e "\n${WHITE}=== CONFIGURAÇÕES AVANÇADAS ===${NC}"
    echo -e "1) Limpar cache manualmente"
    echo -e "2) Limpar logs antigos"
    echo -e "3) Ver configurações do Rclone"
    echo -e "4) Voltar"

    read -p "Opção: " choice
    case $choice in
        1) rm -rfv "$CACHE_DIR"/* ;;
        2) find "$LOG_DIR" -type f -mtime +5 -delete ;;
        3) rclone config show ;;
        4) return ;;
        *) echo -e "${RED}Opção inválida!${NC}" ;;
    esac
}

main_menu() {
    while true; do
        show_header

        # Menu em formato de tabela
        echo -e "${GREEN} GERENCIAMENTO BÁSICO ${NC}"
        echo -e "${MENU[0]}\t${MENU[1]}"
        echo -e "${MENU[2]}"

        echo -e "\n${BLUE} OPERAÇÕES DE MONTAGEM ${NC}"
        echo -e "${MENU[3]}\t${MENU[4]}"
        echo -e "${MENU[5]}\t${MENU[6]}"

        echo -e "\n${CYAN} FERRAMENTAS ${NC}"
        echo -e "${MENU[7]}\t${MENU[8]}"
        echo -e "${MENU[9]}"

        echo -e "\n${RED} SAIR ${NC}"
        echo -e "${MENU[10]}"

        echo -e "\n${BLUE}══════════════════════════════════════════════${NC}"

        read -p "Selecione uma opção (1-11): " choice

        case $choice in
            1) install_rclone ;;
            2) update_rclone ;;
            3) setup_mount_directory ;;
            4) mount_single_remote ;;
            5) unmount_single_remote ;;
            6) mount_all_remotes ;;
            7) unmount_all_remotes ;;
            8) show_cache_usage ;;
            9) show_rclone_logs ;;
            10) advanced_settings ;;
            11) echo -e "${MAGENTA}Até logo!${NC}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida!${NC}" ;;
        esac

        read -p "Pressione Enter para continuar..."
    done
}

# Iniciar
main_menu