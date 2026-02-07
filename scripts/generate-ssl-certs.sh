#!/bin/bash

# Script para Gerar Certificados SSL para PostgreSQL
# =================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
SECRETS_DIR="./secrets"
CERT_VALIDITY_DAYS=365

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

# Função para verificar se openssl está instalado
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL não está instalado. Por favor, instale o OpenSSL primeiro."
        exit 1
    fi
}

# Função para criar diretório de secrets
create_secrets_dir() {
    if [ ! -d "$SECRETS_DIR" ]; then
        log "Criando diretório de secrets: $SECRETS_DIR"
        mkdir -p "$SECRETS_DIR"
        chmod 700 "$SECRETS_DIR"
    fi
}

# Função para gerar chave privada da CA
generate_ca_key() {
    log "Gerando chave privada da CA..."
    openssl genrsa -out "$SECRETS_DIR/ca.key" 4096
    chmod 600 "$SECRETS_DIR/ca.key"
}

# Função para gerar certificado da CA
generate_ca_cert() {
    log "Gerando certificado da CA..."
    openssl req -new -x509 -days $CERT_VALIDITY_DAYS -key "$SECRETS_DIR/ca.key" -out "$SECRETS_DIR/ca.crt" \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=CRM-Juridico/OU=IT/CN=CRM-Juridico-CA"
    chmod 644 "$SECRETS_DIR/ca.crt"
}

# Função para gerar chave privada do servidor
generate_server_key() {
    log "Gerando chave privada do servidor..."
    openssl genrsa -out "$SECRETS_DIR/server.key" 2048
    chmod 600 "$SECRETS_DIR/server.key"
}

# Função para gerar requisição de certificado do servidor
generate_server_csr() {
    log "Gerando requisição de certificado do servidor..."
    openssl req -new -key "$SECRETS_DIR/server.key" -out "$SECRETS_DIR/server.csr" \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=CRM-Juridico/OU=IT/CN=postgres"
}

# Função para gerar certificado do servidor
generate_server_cert() {
    log "Gerando certificado do servidor..."
    
    # Criar arquivo de configuração para o certificado
    cat > "$SECRETS_DIR/server.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = BR
ST = SP
L = SaoPaulo
O = CRM-Juridico
OU = IT
CN = postgres

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = postgres
DNS.3 = crm-juridico-db
IP.1 = 127.0.0.1
IP.2 = 172.20.0.2
EOF

    openssl x509 -req -in "$SECRETS_DIR/server.csr" -CA "$SECRETS_DIR/ca.crt" -CAkey "$SECRETS_DIR/ca.key" \
        -CAcreateserial -out "$SECRETS_DIR/server.crt" -days $CERT_VALIDITY_DAYS \
        -extensions v3_req -extfile "$SECRETS_DIR/server.conf"
    
    chmod 644 "$SECRETS_DIR/server.crt"
}

# Função para gerar certificado do cliente
generate_client_cert() {
    local client_name="${1:-client}"
    
    log "Gerando certificado do cliente: $client_name"
    
    # Gerar chave privada do cliente
    openssl genrsa -out "$SECRETS_DIR/${client_name}.key" 2048
    chmod 600 "$SECRETS_DIR/${client_name}.key"
    
    # Gerar requisição de certificado do cliente
    openssl req -new -key "$SECRETS_DIR/${client_name}.key" -out "$SECRETS_DIR/${client_name}.csr" \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=CRM-Juridico/OU=IT/CN=${client_name}"
    
    # Gerar certificado do cliente
    openssl x509 -req -in "$SECRETS_DIR/${client_name}.csr" -CA "$SECRETS_DIR/ca.crt" -CAkey "$SECRETS_DIR/ca.key" \
        -CAcreateserial -out "$SECRETS_DIR/${client_name}.crt" -days $CERT_VALIDITY_DAYS
    
    chmod 644 "$SECRETS_DIR/${client_name}.crt"
    
    # Remover arquivos temporários
    rm -f "$SECRETS_DIR/${client_name}.csr"
}

# Função para limpar arquivos temporários
cleanup_temp_files() {
    log "Limpando arquivos temporários..."
    rm -f "$SECRETS_DIR/server.csr" "$SECRETS_DIR/server.conf" "$SECRETS_DIR/ca.srl"
}

# Função para verificar certificados
verify_certificates() {
    log "Verificando certificados gerados..."
    
    if [ -f "$SECRETS_DIR/ca.crt" ]; then
        info "CA Certificate:"
        openssl x509 -in "$SECRETS_DIR/ca.crt" -text -noout | grep -E "(Subject:|Not Before:|Not After:)"
    fi
    
    if [ -f "$SECRETS_DIR/server.crt" ]; then
        info "Server Certificate:"
        openssl x509 -in "$SECRETS_DIR/server.crt" -text -noout | grep -E "(Subject:|Not Before:|Not After:)"
    fi
    
    if [ -f "$SECRETS_DIR/client.crt" ]; then
        info "Client Certificate:"
        openssl x509 -in "$SECRETS_DIR/client.crt" -text -noout | grep -E "(Subject:|Not Before:|Not After:)"
    fi
}

# Função para mostrar informações de uso
show_usage() {
    echo "Script para Gerar Certificados SSL para PostgreSQL"
    echo "=================================================="
    echo ""
    echo "Uso: $0 [comando] [opções]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  generate    - Gerar todos os certificados (padrão)"
    echo "  ca          - Gerar apenas certificado da CA"
    echo "  server      - Gerar apenas certificado do servidor"
    echo "  client      - Gerar certificado do cliente"
    echo "  verify      - Verificar certificados existentes"
    echo "  clean       - Limpar todos os certificados"
    echo "  help        - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 generate"
    echo "  $0 client myapp"
    echo "  $0 verify"
    echo "  $0 clean"
}

# Função para limpar todos os certificados
clean_certificates() {
    warning "Isso irá remover todos os certificados SSL!"
    read -p "Tem certeza? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removendo todos os certificados..."
        rm -rf "$SECRETS_DIR"
        log "Certificados removidos com sucesso!"
    else
        log "Operação cancelada."
    fi
}

# Função principal para gerar todos os certificados
generate_all() {
    log "Iniciando geração de certificados SSL..."
    
    check_openssl
    create_secrets_dir
    
    generate_ca_key
    generate_ca_cert
    generate_server_key
    generate_server_csr
    generate_server_cert
    generate_client_cert "client"
    
    cleanup_temp_files
    verify_certificates
    
    log "Certificados SSL gerados com sucesso!"
    info "Certificados salvos em: $SECRETS_DIR"
    info "Lembre-se de manter as chaves privadas seguras!"
}

# Menu principal
case "${1:-generate}" in
    "generate")
        generate_all
        ;;
    "ca")
        check_openssl
        create_secrets_dir
        generate_ca_key
        generate_ca_cert
        verify_certificates
        ;;
    "server")
        check_openssl
        create_secrets_dir
        generate_server_key
        generate_server_csr
        generate_server_cert
        cleanup_temp_files
        verify_certificates
        ;;
    "client")
        check_openssl
        create_secrets_dir
        generate_client_cert "${2:-client}"
        verify_certificates
        ;;
    "verify")
        verify_certificates
        ;;
    "clean")
        clean_certificates
        ;;
    "help"|*)
        show_usage
        ;;
esac
