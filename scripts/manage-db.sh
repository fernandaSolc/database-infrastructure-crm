#!/bin/bash

# Script de Gerenciamento do Banco de Dados CRM Jurídico
# =====================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
COMPOSE_FILE="docker-compose.yml"
ENV_FILE="config.env"

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

# Função para verificar se o Docker está rodando
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker não está rodando. Por favor, inicie o Docker primeiro."
        exit 1
    fi
}

# Função para verificar se o arquivo de configuração existe
check_config() {
    if [ ! -f "$ENV_FILE" ]; then
        error "Arquivo de configuração não encontrado: $ENV_FILE"
        info "Copie o arquivo env.example para config.env e configure as variáveis:"
        info "cp env.example config.env"
        exit 1
    fi
}

# Função para carregar variáveis de ambiente
load_env() {
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        log "Variáveis de ambiente carregadas de $ENV_FILE"
    fi
}

# Função para iniciar o banco de dados
start_database() {
    log "Iniciando banco de dados PostgreSQL..."
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d postgres
    
    log "Aguardando banco de dados estar pronto..."
    sleep 10
    
    # Verificar se o banco está saudável
    if docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps postgres | grep -q "Up (healthy)"; then
        log "Banco de dados iniciado com sucesso!"
        info "Conecte-se usando: psql -h localhost -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
    else
        error "Falha ao iniciar o banco de dados. Verifique os logs:"
        info "docker-compose -f $COMPOSE_FILE logs postgres"
        exit 1
    fi
}

# Função para parar o banco de dados
stop_database() {
    log "Parando banco de dados PostgreSQL..."
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
    
    log "Banco de dados parado com sucesso!"
}

# Função para reiniciar o banco de dados
restart_database() {
    log "Reiniciando banco de dados PostgreSQL..."
    stop_database
    sleep 5
    start_database
}

# Função para mostrar status do banco
status_database() {
    log "Status do banco de dados:"
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo ""
    info "Informações de conexão:"
    info "Host: localhost"
    info "Porta: ${POSTGRES_PORT:-5432}"
    info "Banco: ${POSTGRES_DB}"
    info "Usuário: ${POSTGRES_USER}"
}

# Função para mostrar logs
show_logs() {
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f postgres
}

# Função para fazer backup
backup_database() {
    log "Iniciando backup do banco de dados..."
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" run --rm backup
}

# Função para iniciar PgAdmin
start_pgadmin() {
    log "Iniciando PgAdmin..."
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --profile admin up -d pgadmin
    
    log "PgAdmin iniciado com sucesso!"
    info "Acesse: http://localhost:${PGADMIN_PORT:-8080}"
    info "Email: ${PGADMIN_EMAIL}"
    info "Senha: ${PGADMIN_PASSWORD}"
}

# Função para parar PgAdmin
stop_pgadmin() {
    log "Parando PgAdmin..."
    check_docker
    check_config
    load_env
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --profile admin down
}

# Função para conectar ao banco via psql
connect_database() {
    check_docker
    check_config
    load_env
    
    log "Conectando ao banco de dados..."
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
}

# Função para executar SQL
execute_sql() {
    local sql_file="$1"
    
    if [ -z "$sql_file" ]; then
        error "Arquivo SQL não especificado!"
        exit 1
    fi
    
    if [ ! -f "$sql_file" ]; then
        error "Arquivo SQL não encontrado: $sql_file"
        exit 1
    fi
    
    check_docker
    check_config
    load_env
    
    log "Executando SQL: $sql_file"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$sql_file"
}

# Função para mostrar ajuda
show_help() {
    echo "Script de Gerenciamento do Banco de Dados CRM Jurídico"
    echo "======================================================"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  start      - Iniciar banco de dados"
    echo "  stop       - Parar banco de dados"
    echo "  restart    - Reiniciar banco de dados"
    echo "  status     - Mostrar status do banco"
    echo "  logs       - Mostrar logs do banco"
    echo "  backup     - Fazer backup do banco"
    echo "  pgadmin    - Iniciar PgAdmin"
    echo "  stop-admin - Parar PgAdmin"
    echo "  connect    - Conectar ao banco via psql"
    echo "  exec       - Executar arquivo SQL"
    echo "  help       - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 start"
    echo "  $0 backup"
    echo "  $0 exec scripts/init-db.sql"
    echo "  $0 connect"
}

# Menu principal
case "${1:-help}" in
    "start")
        start_database
        ;;
    "stop")
        stop_database
        ;;
    "restart")
        restart_database
        ;;
    "status")
        status_database
        ;;
    "logs")
        show_logs
        ;;
    "backup")
        backup_database
        ;;
    "pgadmin")
        start_pgadmin
        ;;
    "stop-admin")
        stop_pgadmin
        ;;
    "connect")
        connect_database
        ;;
    "exec")
        execute_sql "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac
