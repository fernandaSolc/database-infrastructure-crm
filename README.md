# Infraestrutura de Banco de Dados CRM Jurídico

Este projeto fornece uma infraestrutura segura de banco de dados PostgreSQL usando Docker, configurada para servir como backend central para múltiplos projetos do CRM Jurídico.

## 🏗️ Arquitetura

```
database-infrastructure/
├── docker-compose.yml          # Configuração principal do Docker
├── config.env                  # Variáveis de ambiente
├── env.example                 # Exemplo de configuração
├── postgres/
│   ├── postgresql.conf         # Configurações do PostgreSQL
│   └── pg_hba.conf            # Configurações de autenticação
├── scripts/
│   ├── init-db.sql            # Script de inicialização
│   ├── backup.sh              # Script de backup
│   ├── manage-db.sh           # Gerenciador do banco
│   └── generate-ssl-certs.sh  # Gerador de certificados SSL
├── secrets/                   # Certificados SSL (gerados)
└── backups/                   # Backups do banco
```

## 🔒 Recursos de Segurança

### 1. Autenticação e Autorização
- **SCRAM-SHA-256**: Criptografia de senhas
- **Usuários específicos**: Diferentes usuários para diferentes propósitos
- **Row Level Security (RLS)**: Controle de acesso a nível de linha
- **Políticas de segurança**: Controle granular de permissões

### 2. Criptografia
- **SSL/TLS**: Conexões criptografadas obrigatórias
- **Certificados personalizados**: CA própria para controle total
- **Ciphers seguros**: Apenas algoritmos de criptografia seguros

### 3. Auditoria e Logging
- **Log de conexões**: Registro de todas as conexões
- **Log de operações**: Registro de modificações de dados
- **Tabela de auditoria**: Histórico completo de mudanças
- **Logs estruturados**: Formato padronizado para análise

### 4. Rede e Isolamento
- **Rede Docker isolada**: Subnet dedicada (172.20.0.0/16)
- **Firewall de aplicação**: pg_hba.conf restritivo
- **Portas específicas**: Controle de acesso por porta

## 🚀 Início Rápido

### 1. Configuração Inicial

```bash
# Copiar arquivo de configuração
cp env.example config.env

# Editar configurações (IMPORTANTE: alterar senhas!)
nano config.env
```

### 2. Gerar Certificados SSL

```bash
# Gerar todos os certificados SSL
./scripts/generate-ssl-certs.sh generate

# Ou gerar apenas certificado do servidor
./scripts/generate-ssl-certs.sh server
```

### 3. Iniciar o Banco de Dados

```bash
# Iniciar banco de dados
./scripts/manage-db.sh start

# Verificar status
./scripts/manage-db.sh status
```

### 4. Conectar ao Banco

```bash
# Via psql
./scripts/manage-db.sh connect

# Via PgAdmin (opcional)
./scripts/manage-db.sh pgadmin
# Acesse: http://localhost:8080
```

## 📋 Comandos Disponíveis

### Gerenciamento do Banco

```bash
# Iniciar/parar/reiniciar
./scripts/manage-db.sh start
./scripts/manage-db.sh stop
./scripts/manage-db.sh restart

# Status e logs
./scripts/manage-db.sh status
./scripts/manage-db.sh logs

# Backup
./scripts/manage-db.sh backup

# Executar SQL
./scripts/manage-db.sh exec scripts/init-db.sql
```

### Gerenciamento de Certificados

```bash
# Gerar certificados
./scripts/generate-ssl-certs.sh generate

# Verificar certificados
./scripts/generate-ssl-certs.sh verify

# Limpar certificados
./scripts/generate-ssl-certs.sh clean
```

## 🔧 Configurações de Produção

### 1. Variáveis de Ambiente Críticas

```bash
# config.env
POSTGRES_PASSWORD=SenhaMuitoSegura123!@#
PGADMIN_PASSWORD=AdminSeguro456!@#
```

### 2. Configurações de Rede

- **Subnet**: 172.20.0.0/16
- **Porta PostgreSQL**: 5432 (configurável)
- **Porta PgAdmin**: 8080 (configurável)

### 3. Configurações de Backup

- **Retenção**: 30 dias (configurável)
- **Compressão**: Gzip automático
- **Verificação**: Integridade automática

## 🛡️ Checklist de Segurança

### ✅ Configurações Obrigatórias

- [ ] Alterar senhas padrão em `config.env`
- [ ] Gerar certificados SSL únicos
- [ ] Configurar firewall do host
- [ ] Configurar backup automático
- [ ] Monitorar logs de auditoria
- [ ] Atualizar regularmente as imagens Docker

### ✅ Configurações Recomendadas

- [ ] Configurar VPN para acesso remoto
- [ ] Implementar monitoramento de performance
- [ ] Configurar alertas de segurança
- [ ] Documentar procedimentos de recuperação
- [ ] Treinar equipe em procedimentos de segurança

## 📊 Monitoramento

### Logs de Auditoria

```sql
-- Verificar logs de auditoria
SELECT * FROM audit.audit_log 
ORDER BY timestamp DESC 
LIMIT 100;

-- Estatísticas de conexão
SELECT * FROM pg_stat_activity;
```

### Métricas de Performance

```sql
-- Estatísticas de queries
SELECT * FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;
```

## 🔄 Backup e Recuperação

### Backup Automático

```bash
# Backup manual
./scripts/manage-db.sh backup

# Backup via cron (exemplo)
0 2 * * * /path/to/database-infrastructure/scripts/manage-db.sh backup
```

### Restauração

```bash
# Listar backups disponíveis
ls -la backups/

# Restaurar backup específico
./scripts/backup.sh restore backups/backup_crm_juridico_20231201_020000.sql.gz
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Banco não inicia**
   ```bash
   # Verificar logs
   ./scripts/manage-db.sh logs
   
   # Verificar configurações
   docker-compose config
   ```

2. **Erro de SSL**
   ```bash
   # Regenerar certificados
   ./scripts/generate-ssl-certs.sh clean
   ./scripts/generate-ssl-certs.sh generate
   ```

3. **Problemas de conectividade**
   ```bash
   # Verificar rede Docker
   docker network ls
   docker network inspect database-infrastructure_crm-network
   ```

## 📚 Recursos Adicionais

- [Documentação PostgreSQL](https://www.postgresql.org/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)
- [SSL/TLS Configuration](https://www.postgresql.org/docs/current/ssl-tcp.html)

## 🤝 Suporte

Para dúvidas ou problemas:
1. Verifique os logs: `./scripts/manage-db.sh logs`
2. Consulte a documentação PostgreSQL
3. Verifique as configurações de rede e SSL
4. Entre em contato com a equipe de infraestrutura

---

**⚠️ IMPORTANTE**: Este é um ambiente de produção. Sempre faça backup antes de alterações críticas e mantenha as senhas seguras!
