#!/bin/bash

# Script de Setup Inicial - Infraestrutura de Banco de Dados CRM Jurídico
# =======================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Função para logging colorido
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    header "Verificando Pré-requisitos"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado. Por favor, instale o Docker primeiro."
        exit 1
    fi
    success "Docker encontrado: $(docker --version)"
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado. Por favor, instale o Docker Compose primeiro."
        exit 1
    fi
    success "Docker Compose encontrado: $(docker-compose --version)"
    
    # Verificar OpenSSL
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL não está instalado. Por favor, instale o OpenSSL primeiro."
        exit 1
    fi
    success "OpenSSL encontrado: $(openssl version)"
    
    # Verificar se Docker está rodando
    if ! docker info >/dev/null 2>&1; then
        error "Docker não está rodando. Por favor, inicie o Docker primeiro."
        exit 1
    fi
    success "Docker está rodando"
}

# Função para configurar arquivo de ambiente
setup_environment() {
    header "Configurando Variáveis de Ambiente"
    
    if [ ! -f "config.env" ]; then
        if [ -f "env.example" ]; then
            log "Copiando arquivo de exemplo..."
            cp env.example config.env
            success "Arquivo config.env criado"
        else
            error "Arquivo env.example não encontrado!"
            exit 1
        fi
    else
        warning "Arquivo config.env já existe"
    fi
    
    # Gerar senhas seguras se necessário
    if grep -q "SuperSecurePassword123" config.env; then
        warning "Usando senhas padrão! Recomendamos alterar as senhas em config.env"
        info "Você pode gerar senhas seguras com: openssl rand -base64 32"
    fi
}

# Função para gerar certificados SSL
setup_ssl_certificates() {
    header "Configurando Certificados SSL"
    
    if [ ! -d "secrets" ] || [ ! -f "secrets/server.crt" ]; then
        log "Gerando certificados SSL..."
        ./scripts/generate-ssl-certs.sh generate
        success "Certificados SSL gerados com sucesso"
    else
        warning "Certificados SSL já existem"
        info "Para regenerar, execute: ./scripts/generate-ssl-certs.sh clean && ./scripts/generate-ssl-certs.sh generate"
    fi
}

# Função para criar diretórios necessários
create_directories() {
    header "Criando Diretórios Necessários"
    
    directories=("backups" "logs" "secrets")
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chmod 700 "$dir"
            success "Diretório criado: $dir"
        else
            info "Diretório já existe: $dir"
        fi
    done
}

# Função para configurar permissões
setup_permissions() {
    header "Configurando Permissões"
    
    # Tornar scripts executáveis
    chmod +x scripts/*.sh
    success "Scripts tornados executáveis"
    
    # Configurar permissões do diretório secrets
    if [ -d "secrets" ]; then
        chmod 700 secrets
        chmod 600 secrets/*.key 2>/dev/null || true
        chmod 644 secrets/*.crt 2>/dev/null || true
        success "Permissões do diretório secrets configuradas"
    fi
}

# Função para testar configuração
test_configuration() {
    header "Testando Configuração"
    
    # Verificar se o docker-compose é válido
    log "Validando docker-compose.yml..."
    if docker-compose config >/dev/null 2>&1; then
        success "docker-compose.yml é válido"
    else
        error "docker-compose.yml contém erros!"
        docker-compose config
        exit 1
    fi
    
    # Verificar se as variáveis de ambiente estão carregadas
    log "Verificando variáveis de ambiente..."
    if [ -f "config.env" ]; then
        source config.env
        if [ -n "$POSTGRES_DB" ] && [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ]; then
            success "Variáveis de ambiente configuradas"
        else
            error "Variáveis de ambiente essenciais não encontradas!"
            exit 1
        fi
    else
        error "Arquivo config.env não encontrado!"
        exit 1
    fi
}

# Função para iniciar o banco de dados
start_database() {
    header "Iniciando Banco de Dados"
    
    log "Iniciando PostgreSQL..."
    ./scripts/manage-db.sh start
    
    # Aguardar o banco estar pronto
    log "Aguardando banco de dados estar pronto..."
    sleep 15
    
    # Verificar se está funcionando
    if ./scripts/manage-db.sh status | grep -q "Up (healthy)"; then
        success "Banco de dados iniciado com sucesso!"
    else
        error "Falha ao iniciar o banco de dados"
        info "Verifique os logs com: ./scripts/manage-db.sh logs"
        exit 1
    fi
}

# Função para executar script de inicialização
initialize_database() {
    header "Inicializando Banco de Dados"
    
    log "Executando script de inicialização..."
    ./scripts/manage-db.sh exec scripts/init-db.sql
    
    success "Banco de dados inicializado com sucesso!"
}

# Função para mostrar informações de conexão
show_connection_info() {
    header "Informações de Conexão"
    
    source config.env
    
    echo ""
    info "Banco de dados PostgreSQL:"
    echo "  Host: localhost"
    echo "  Porta: ${POSTGRES_PORT:-5432}"
    echo "  Banco: ${POSTGRES_DB}"
    echo "  Usuário: ${POSTGRES_USER}"
    echo "  Senha: [configurada em config.env]"
    echo ""
    
    info "PgAdmin (opcional):"
    echo "  URL: http://localhost:${PGADMIN_PORT:-8080}"
    echo "  Email: ${PGADMIN_EMAIL}"
    echo "  Senha: [configurada em config.env]"
    echo ""
    
    info "Comandos úteis:"
    echo "  Status: ./scripts/manage-db.sh status"
    echo "  Logs: ./scripts/manage-db.sh logs"
    echo "  Backup: ./scripts/manage-db.sh backup"
    echo "  Conectar: ./scripts/manage-db.sh connect"
    echo "  PgAdmin: ./scripts/manage-db.sh pgadmin"
    echo ""
}

# Função para mostrar próximos passos
show_next_steps() {
    header "Próximos Passos"
    
    echo ""
    info "1. Segurança:"
    echo "   - Altere as senhas em config.env"
    echo "   - Configure firewall do host"
    echo "   - Configure backup automático"
    echo ""
    
    info "2. Desenvolvimento:"
    echo "   - Conecte seus projetos ao banco"
    echo "   - Use as credenciais em config.env"
    echo "   - Configure SSL nas aplicações"
    echo ""
    
    info "3. Produção:"
    echo "   - Configure monitoramento"
    echo "   - Implemente alertas"
    echo "   - Documente procedimentos"
    echo ""
    
    warning "IMPORTANTE: Mantenha as senhas e certificados seguros!"
    echo ""
}

# Função principal
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║    Infraestrutura de Banco de Dados CRM Jurídico            ║"
    echo "║                    Setup Inicial                             ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    check_prerequisites
    setup_environment
    create_directories
    setup_permissions
    setup_ssl_certificates
    test_configuration
    start_database
    initialize_database
    show_connection_info
    show_next_steps
    
    success "Setup concluído com sucesso! 🎉"
    echo ""
    info "Para parar o banco: ./scripts/manage-db.sh stop"
    info "Para reiniciar: ./scripts/manage-db.sh restart"
    echo ""
}

# Executar função principal
main "$@"
