#!/bin/bash

# Script para inicializar postgres, colocar no host em
# /data/compose/11/init-data.sh

set -e

echo "Iniciando criação de banco de dados e usuário..."

# Conecta ao banco de dados 'postgres' (padrão) para criar o novo banco de dados
# Usando bloco DO $$BEGIN IF NOT EXISTS... END$$; para CREATE DATABASE
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    DO
    \$do\$
    BEGIN
       IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB') THEN
          CREATE DATABASE "$POSTGRES_DB";
       END IF;
    END
    \$do\$;
EOSQL

echo "Banco de dados '${POSTGRES_DB}' criado (se não existia) ou já existente."

# Conecta ao banco de dados recém-criado para criar o usuário e conceder permissões
# Adicionado "IF NOT EXISTS" para a criação do usuário
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Cria o usuário se ele não existir
    DO
    \$do\$
    BEGIN
       IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$POSTGRES_NON_ROOT_USER') THEN
          CREATE USER "$POSTGRES_NON_ROOT_USER" WITH PASSWORD '$POSTGRES_NON_ROOT_PASSWORD';
       END IF;
    END
    \$do\$;
    
    -- Concede todos os privilégios no banco de dados para o usuário
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_DB" TO "$POSTGRES_NON_ROOT_USER";
    
    -- Concede permissão para criar no banco de dados, necessário para extensões
    GRANT CREATE ON DATABASE "$POSTGRES_DB" TO "$POSTGRES_NON_ROOT_USER";
    
    -- Concede permissões de uso e criação no schema public
    GRANT USAGE ON SCHEMA public TO "$POSTGRES_NON_ROOT_USER";
    GRANT CREATE ON SCHEMA public TO "$POSTGRES_NON_ROOT_USER";
    
    -- Concede permissão para criar objetos futuros no schema public para o usuariosemroot
    ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_NON_ROOT_USER" IN SCHEMA public GRANT ALL ON TABLES TO "$POSTGRES_NON_ROOT_USER";
    ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_NON_ROOT_USER" IN SCHEMA public GRANT ALL ON SEQUENCES TO "$POSTGRES_NON_ROOT_USER";
    ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_NON_ROOT_USER" IN SCHEMA public GRANT ALL ON FUNCTIONS TO "$POSTGRES_NON_ROOT_USER";

EOSQL

echo "Usuário '${POSTGRES_NON_ROOT_USER}' criado (se não existia) e permissões concedidas no banco de dados '${POSTGRES_DB}'."
