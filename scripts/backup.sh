#!/bin/bash

# Script de Backup Automático do PostgreSQL
# =========================================

set -e

# Configurações
BACKUP_DIR="/backups"
DB_NAME="${POSTGRES_DB:-crm_juridico}"
DB_USER="${POSTGRES_USER:-crm_admin}"
DB_HOST="${PGHOST:-postgres}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${DB_NAME}_${TIMESTAMP}.sql"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para limpeza de backups antigos
cleanup_old_backups() {
    log "Removendo backups mais antigos que $RETENTION_DAYS dias..."
    find "$BACKUP_DIR" -name "backup_${DB_NAME}_*.sql" -type f -mtime +$RETENTION_DAYS -delete
    log "Limpeza de backups antigos concluída."
}

# Função para verificar integridade do backup
verify_backup() {
    local backup_file="$1"
    log "Verificando integridade do backup: $backup_file"
    
    # Verificar se o arquivo existe e não está vazio
    if [ ! -s "$backup_file" ]; then
        log "ERRO: Backup está vazio ou não existe!"
        return 1
    fi
    
    # Verificar se contém dados do PostgreSQL
    if ! grep -q "PostgreSQL database dump" "$backup_file"; then
        log "ERRO: Backup não parece ser um dump válido do PostgreSQL!"
        return 1
    fi
    
    log "Backup verificado com sucesso."
    return 0
}

# Função principal de backup
create_backup() {
    log "Iniciando backup do banco de dados: $DB_NAME"
    
    # Aguardar o banco estar disponível
    until pg_isready -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME"; do
        log "Aguardando banco de dados estar disponível..."
        sleep 2
    done
    
    # Criar backup
    log "Criando backup: $BACKUP_FILE"
    pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
        --verbose \
        --no-password \
        --format=plain \
        --no-owner \
        --no-privileges \
        --clean \
        --if-exists \
        --create \
        > "$BACKUP_FILE"
    
    # Verificar backup
    if verify_backup "$BACKUP_FILE"; then
        log "Backup criado com sucesso: $BACKUP_FILE"
        
        # Comprimir backup
        gzip "$BACKUP_FILE"
        log "Backup comprimido: ${BACKUP_FILE}.gz"
        
        # Mostrar informações do backup
        local backup_size=$(du -h "${BACKUP_FILE}.gz" | cut -f1)
        log "Tamanho do backup: $backup_size"
        
        return 0
    else
        log "ERRO: Falha na criação do backup!"
        rm -f "$BACKUP_FILE"
        return 1
    fi
}

# Função para backup incremental (WAL)
create_wal_backup() {
    log "Criando backup incremental (WAL)..."
    
    # Esta função seria implementada para backups incrementais
    # usando pg_basebackup ou pg_receivewal
    log "Backup incremental não implementado ainda."
}

# Função para restaurar backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log "ERRO: Arquivo de backup não especificado!"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log "ERRO: Arquivo de backup não encontrado: $backup_file"
        return 1
    fi
    
    log "Restaurando backup: $backup_file"
    
    # Descomprimir se necessário
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME"
    else
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" < "$backup_file"
    fi
    
    log "Backup restaurado com sucesso."
}

# Menu principal
case "${1:-backup}" in
    "backup")
        create_backup
        cleanup_old_backups
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "verify")
        verify_backup "$2"
        ;;
    *)
        echo "Uso: $0 [backup|restore|cleanup|verify] [arquivo]"
        echo "  backup  - Criar backup (padrão)"
        echo "  restore - Restaurar backup"
        echo "  cleanup - Limpar backups antigos"
        echo "  verify  - Verificar integridade do backup"
        exit 1
        ;;
esac
