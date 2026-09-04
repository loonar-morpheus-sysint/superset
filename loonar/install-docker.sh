#!/usr/bin/env bash
#
# install-docker.sh
#
# Instalação segura do Docker Engine + Docker Compose (plugin) no Ubuntu,
# seguindo as boas práticas da documentação oficial:
#   - https://docs.docker.com/engine/install/ubuntu/
#   - https://docs.docker.com/engine/install/linux-postinstall/
#
# O que este script faz:
#   1. Valida pré-requisitos (Ubuntu 64-bit, sudo, arquitetura suportada)
#   2. Remove pacotes conflitantes (docker.io, docker-compose legado, podman-docker, etc.)
#   3. Configura o repositório APT oficial do Docker (chave GPG + formato deb822)
#   4. Instala: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
#   5. Habilita e inicia os serviços docker e containerd (systemd)
#   6. Adiciona o usuário ao grupo 'docker' (uso sem sudo)
#   7. Verifica a instalação (docker version, docker compose version, hello-world)
#
# Uso:
#   ./install-docker.sh          (como usuário normal com acesso sudo)
#   sudo ./install-docker.sh     (também funciona; adiciona o usuário que chamou o sudo ao grupo docker)
#

set -euo pipefail

COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_CYAN="\033[36m"
COLOR_MAGENTA="\033[35m"

say_info() {
	printf "%b\n" "${COLOR_CYAN}${COLOR_BOLD}ℹ️  $*${COLOR_RESET}"
}

say_ok() {
	printf "%b\n" "${COLOR_GREEN}${COLOR_BOLD}✅ $*${COLOR_RESET}"
}

say_warn() {
	printf "%b\n" "${COLOR_YELLOW}${COLOR_BOLD}⚠️  $*${COLOR_RESET}"
}

say_err() {
	printf "%b\n" "${COLOR_RED}${COLOR_BOLD}❌ $*${COLOR_RESET}" >&2
}

say_action() {
	printf "%b\n" "${COLOR_MAGENTA}${COLOR_BOLD}🚀 $*${COLOR_RESET}"
}

# Pergunta interativa sim/não. Uso: confirm_continue "Pergunta?" && comando
confirm_continue() {
	local prompt="$1"
	local reply
	read -r -p "$(printf "%b" "${COLOR_YELLOW}${COLOR_BOLD}❓ ${prompt} [s/N]: ${COLOR_RESET}")" reply
	case "${reply:-N}" in
		[sS] | [sS][iI][mM] | [yY] | [yY][eE][sS]) return 0 ;;
		*) return 1 ;;
	esac
}

die() {
	say_err "$*"
	exit 1
}

#######################################
# 1. Pré-requisitos
#######################################

check_prerequisites() {
	say_info "Verificando pré-requisitos..."

	# Deve ser Ubuntu (documentação oficial suporta apenas Ubuntu; derivados não são suportados)
	if [[ ! -f /etc/os-release ]]; then
		die "Não foi possível identificar o sistema operacional (/etc/os-release ausente)."
	fi

	# shellcheck disable=SC1091
	. /etc/os-release
	if [[ "${ID:-}" != "ubuntu" ]]; then
		say_warn "Este script foi feito para Ubuntu. Sistema detectado: ${PRETTY_NAME:-desconhecido}."
		confirm_continue "Continuar mesmo assim?" || die "Instalação cancelada."
	fi

	# Versões suportadas conforme a documentação oficial (LTS)
	local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
	case "${codename}" in
		jammy | noble | resolute)
			say_ok "Ubuntu ${VERSION_ID:-?} (${codename}) — versão suportada."
			;;
		*)
			say_warn "Codinome '${codename}' não consta na lista oficial de versões suportadas (jammy, noble, resolute)."
			confirm_continue "Continuar mesmo assim?" || die "Instalação cancelada."
			;;
	esac

	# Arquiteturas suportadas: x86_64/amd64, armhf, arm64, s390x, ppc64le
	local arch
	arch="$(dpkg --print-architecture)"
	case "${arch}" in
		amd64 | armhf | arm64 | s390x | ppc64el)
			say_ok "Arquitetura ${arch} — suportada."
			;;
		*)
			die "Arquitetura '${arch}' não é suportada pelo Docker Engine no Ubuntu."
			;;
	esac

	# Acesso sudo é obrigatório
	if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
		say_info "Este script precisa de privilégios sudo. Você poderá ser solicitado a digitar sua senha."
		sudo -v || die "Acesso sudo não disponível para este usuário."
	fi

	# Determina o usuário real (quem chamou o script), mesmo se rodado com sudo
	TARGET_USER="${SUDO_USER:-${USER}}"
	if [[ "${TARGET_USER}" == "root" ]]; then
		say_warn "Script executado como root puro. Nenhum usuário não-root será adicionado ao grupo docker automaticamente."
		read -r -p "$(printf "%b" "${COLOR_YELLOW}${COLOR_BOLD}❓ Informe o usuário que deve usar o Docker sem sudo (ou Enter para pular): ${COLOR_RESET}")" TARGET_USER
		TARGET_USER="${TARGET_USER:-}"
	fi

	if [[ -n "${TARGET_USER}" ]] && ! id "${TARGET_USER}" &>/dev/null; then
		die "Usuário '${TARGET_USER}' não existe no sistema."
	fi
}

#######################################
# 2. Remoção de pacotes conflitantes
#######################################

remove_conflicting_packages() {
	# Lista oficial de pacotes não-oficiais/conflitantes da documentação
	local conflicting=(docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc)
	local installed=()
	local pkg

	for pkg in "${conflicting[@]}"; do
		if dpkg -l "${pkg}" 2>/dev/null | grep -q '^ii'; then
			installed+=("${pkg}")
		fi
	done

	if [[ ${#installed[@]} -eq 0 ]]; then
		say_ok "Nenhum pacote conflitante instalado."
		return 0
	fi

	say_warn "Pacotes conflitantes encontrados: ${installed[*]}"
	say_info "A documentação oficial exige a remoção desses pacotes antes da instalação."
	say_info "Imagens, containers e volumes em /var/lib/docker NÃO serão removidos."

	if confirm_continue "Remover os pacotes conflitantes?"; then
		say_action "Removendo pacotes conflitantes..."
		sudo apt-get remove -y "${installed[@]}"
		say_ok "Pacotes removidos."
	else
		die "Não é possível prosseguir com pacotes conflitantes instalados. Instalação cancelada."
	fi
}

#######################################
# 3. Repositório oficial do Docker
#######################################

setup_docker_repository() {
	say_action "Configurando o repositório APT oficial do Docker..."

	sudo apt-get update
	sudo apt-get install -y ca-certificates curl

	# Chave GPG oficial
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Repositório no formato deb822 (.sources) — formato atual recomendado pela documentação
	local codename arch
	# shellcheck disable=SC1091
	codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
	arch="$(dpkg --print-architecture)"

	sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

	# Remove o formato legado .list, se existir, para evitar duplicidade
	if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
		say_warn "Removendo configuração legada /etc/apt/sources.list.d/docker.list (substituída por docker.sources)."
		sudo rm -f /etc/apt/sources.list.d/docker.list
	fi

	sudo apt-get update
	say_ok "Repositório configurado."
}

#######################################
# 4. Instalação dos pacotes
#######################################

install_docker_packages() {
	say_action "Instalando Docker Engine, CLI, containerd, Buildx e Compose plugin..."
	sudo apt-get install -y \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin
	say_ok "Pacotes instalados."
}

#######################################
# 5. Serviços systemd
#######################################

enable_docker_services() {
	say_action "Habilitando e iniciando os serviços docker e containerd..."
	sudo systemctl enable --now docker.service
	sudo systemctl enable --now containerd.service

	if sudo systemctl is-active --quiet docker.service; then
		say_ok "Serviço docker ativo."
	else
		die "O serviço docker não está ativo. Verifique com: sudo systemctl status docker"
	fi
}

#######################################
# 6. Grupo docker (uso sem sudo)
#######################################

add_user_to_docker_group() {
	if [[ -z "${TARGET_USER}" ]]; then
		say_warn "Nenhum usuário informado; pulando configuração do grupo docker."
		return 0
	fi

	# O pacote normalmente já cria o grupo; garantimos a existência
	if ! getent group docker >/dev/null; then
		say_action "Criando o grupo 'docker'..."
		sudo groupadd docker
	fi

	if id -nG "${TARGET_USER}" | grep -qw docker; then
		say_ok "Usuário '${TARGET_USER}' já pertence ao grupo docker."
		return 0
	fi

	say_warn "ATENÇÃO: o grupo docker concede privilégios equivalentes a root ao usuário."
	if confirm_continue "Adicionar o usuário '${TARGET_USER}' ao grupo docker?"; then
		sudo usermod -aG docker "${TARGET_USER}"
		say_ok "Usuário '${TARGET_USER}' adicionado ao grupo docker."

		# Corrige permissões de ~/.docker caso o usuário tenha usado 'sudo docker' antes
		local user_home
		user_home="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
		if [[ -d "${user_home}/.docker" ]] && [[ ! -w "${user_home}/.docker" ]]; then
			say_warn "Ajustando permissões de ${user_home}/.docker (criado anteriormente via sudo)..."
			sudo chown "${TARGET_USER}":"${TARGET_USER}" "${user_home}/.docker" -R
			sudo chmod g+rwx "${user_home}/.docker" -R
		fi
	else
		say_warn "Usuário não adicionado ao grupo. Será necessário usar 'sudo docker'."
	fi
}

#######################################
# 7. Verificação da instalação
#######################################

verify_installation() {
	say_info "Verificando a instalação..."

	say_info "Versão do Docker Engine:"
	docker version

	say_info "Versão do Docker Compose (plugin):"
	docker compose version || die "Docker Compose plugin não está funcional."

	# Teste funcional com hello-world usando o usuário alvo já com o grupo ativo
	say_action "Executando o teste oficial 'hello-world'..."
	if [[ -n "${TARGET_USER}" ]] && id -nG "${TARGET_USER}" | grep -qw docker; then
		# 'sg' executa o comando com o grupo docker ativo, sem exigir logout/login
		if [[ "${EUID}" -eq 0 ]]; then
			su - "${TARGET_USER}" -c "sg docker -c 'docker run --rm hello-world'"
		elif [[ "${TARGET_USER}" == "${USER}" ]]; then
			sg docker -c "docker run --rm hello-world"
		else
			sudo -u "${TARGET_USER}" sg docker -c "docker run --rm hello-world"
		fi
	else
		sudo docker run --rm hello-world
	fi

	say_ok "Teste hello-world executado com sucesso."
}

#######################################
# Main
#######################################

main() {
	clear
	printf "%b\n" "${COLOR_BOLD}======================================================${COLOR_RESET}"
	printf "%b\n" "${COLOR_BOLD}  Instalação Segura do Docker + Docker Compose (Ubuntu)${COLOR_RESET}"
	printf "%b\n" "${COLOR_BOLD}======================================================${COLOR_RESET}\n"

	check_prerequisites

	if command -v docker &>/dev/null; then
		say_warn "Já existe uma instalação do Docker neste sistema: $(docker --version 2>/dev/null || echo 'versão desconhecida')"
		confirm_continue "Deseja prosseguir com a reinstalação/atualização via repositório oficial?" || die "Instalação cancelada."
	fi

	remove_conflicting_packages
	setup_docker_repository
	install_docker_packages
	enable_docker_services
	add_user_to_docker_group
	verify_installation

	printf "\n"
	say_ok "Instalação concluída com sucesso! 🎉"
	if [[ -n "${TARGET_USER}" ]]; then
		say_warn "Para usar o Docker sem sudo em novas sessões, faça logout e login novamente"
		say_warn "(ou execute: newgrp docker). Em sessões SSH, reconecte-se."
	fi
	say_info "Próximos passos: ./up.sh para subir o ambiente Loonar."
}

main "$@"
