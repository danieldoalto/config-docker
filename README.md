# Configuração Docker para n8n com PostgreSQL, Redis e pgAdmin

Este projeto utiliza Docker Compose para orquestrar uma pilha de serviços incluindo n8n, PostgreSQL, Redis e pgAdmin.

## Visão Geral

A configuração é projetada para fornecer um ambiente de desenvolvimento e produção para o n8n, utilizando:

- **n8n**: Serviço principal da aplicação de automação de fluxo de trabalho.
- **n8n-worker**: Serviço de worker para o n8n, para processar execuções em fila.
- **PostgreSQL**: Banco de dados relacional utilizado pelo n8n para persistência de dados.
- **Redis**: Banco de dados em memória utilizado pelo n8n para gerenciamento de filas (quando `EXECUTIONS_MODE=queue`).
- **pgAdmin**: Ferramenta de administração web para o PostgreSQL.

O script `init-data.sh` é responsável por inicializar o banco de dados PostgreSQL, criando o banco de dados e um usuário não-root com as permissões necessárias, caso ainda não existam. Deve ser colocado no host em: `/data/compose/11/init-data.sh`.

## Pré-requisitos

- Docker: Instruções de instalação
- Docker: [Instruções de instalação](https://docs.docker.com/engine/install/)
- Docker Compose: [Instruções de instalação](https://docs.docker.com/compose/install/) (geralmente incluído com o Docker Desktop)

## Variáveis de Ambiente

Antes de iniciar os serviços, você precisará configurar as seguintes variáveis de ambiente.
Crie um arquivo chamado `.env` no mesmo diretório onde seu arquivo `docker-compose.yml` está localizado.
Preencha-o com o seguinte conteúdo, ajustando os valores conforme necessário:

```env
# ============================
# Configurações do PostgreSQL
# ============================
POSTGRES_USER=admin                 # Usuário root do PostgreSQL
POSTGRES_PASSWORD=admin             # Senha do usuário root do PostgreSQL
POSTGRES_DB=n8n_juscredi            # Nome do banco de dados para o n8n
POSTGRES_NON_ROOT_USER=n8nuser      # Nome do usuário não-root que o n8n usará
POSTGRES_NON_ROOT_PASSWORD=n8npassword # Senha para o usuário não-root

# ===================
# Configurações do n8n
# ===================
ENCRYPTION_KEY=your_strong_encryption_key # Chave de criptografia para o n8n (MUITO IMPORTANTE: gere uma chave segura e única)

# =======================
# Configurações do pgAdmin
# =======================
PGADMIN_DEFAULT_EMAIL=admin@example.com # Email padrão para login no pgAdmin (substitua PGADMIN_MAIL se estiver usando uma versão mais antiga da imagem)
PGADMIN_DEFAULT_PASSWORD=admin          # Senha padrão para login no pgAdmin (substitua PGADMIN_PW se estiver usando uma versão mais antiga da imagem)
```

**Importante sobre `ENCRYPTION_KEY`**: Esta chave é usada para criptografar credenciais no n8n. Deve ser uma string longa, aleatória e segura. Uma vez definida, não a altere, ou as credenciais existentes se tornarão inacessíveis.

## Estrutura dos Serviços

### `postgres`

- **Imagem**: `postgres:16`
- **Descrição**: Serviço de banco de dados PostgreSQL.
- **Persistência**: Os dados são armazenados no volume `db_storage`.
- **Inicialização**: O script `init-data.sh` é executado na primeira inicialização para:
  - Criar o banco de dados `$POSTGRES_DB` (se não existir).
  - Criar o usuário `$POSTGRES_NON_ROOT_USER` com a senha `$POSTGRES_NON_ROOT_PASSWORD` (se não existir).
  - Conceder todas as permissões no banco de dados `$POSTGRES_DB` para o usuário `$POSTGRES_NON_ROOT_USER`.
  - Conceder permissões de `CREATE` no schema `public` e permissões para criar objetos futuros.

### `redis`

- **Imagem**: `redis:6-alpine`
- **Descrição**: Serviço Redis, usado pelo n8n para enfileiramento quando `EXECUTIONS_MODE=queue`.
- **Persistência**: Os dados são armazenados no volume `redis_storage`.

### `pgadmin`

- **Imagem**: `dpage/pgadmin4:latest`
- **Descrição**: Interface web para gerenciar o banco de dados PostgreSQL.
- **Acesso**: Disponível em `http://localhost:5050`.
- **Credenciais**: Definidas por `PGADMIN_DEFAULT_EMAIL` e `PGADMIN_DEFAULT_PASSWORD`.

### `n8n`

- **Imagem**: `docker.n8n.io/n8nio/n8n`
- **Descrição**: Serviço principal do n8n.
- **Configuração**: Utiliza as variáveis de ambiente `DB_POSTGRESDB_*` para conectar ao PostgreSQL e `QUEUE_BULL_REDIS_HOST` para conectar ao Redis.
- **Persistência**: Os dados do n8n (configurações, workflows) são armazenados no volume `n8n_storage` em `/home/node/.n8n`.
- **Acesso**: Disponível em `http://localhost:5678`.

### `n8n-worker`

- **Imagem**: `docker.n8n.io/n8nio/n8n`
- **Comando**: `worker`
- **Descrição**: Serviço worker do n8n, processa tarefas da fila. Depende do serviço `n8n` principal.

## Como Usar

1. **Crie o arquivo `.env`**: Conforme descrito na seção "Variáveis de Ambiente", crie e preencha o arquivo `.env` no mesmo diretório do `docker-compose.yml`.

2. **Inicie os serviços**:
    Navegue até o diretório `config docker` e execute:

    ```bash
    docker-compose up -d
    ```

    O `-d` executa os contêineres em segundo plano.

3. **Acesse os serviços**:
    - **n8n**: `http://localhost:5678`
    - **pgAdmin**: `http://localhost:5050` (use `PGADMIN_DEFAULT_EMAIL` e `PGADMIN_DEFAULT_PASSWORD` para logar)

4. **Verifique os logs**:
    Para ver os logs de um serviço específico (por exemplo, `n8n`):

    ```bash
    docker-compose logs -f n8n
    ```

    Para ver todos os logs:

    ```bash
    docker-compose logs -f
    ```

5. **Pare os serviços**:
    Para parar todos os serviços:

    ```bash
    docker-compose down
    ```

    Se você quiser remover os volumes (ATENÇÃO: isso apagará todos os dados persistidos, como dados do banco, workflows do n8n, etc.):

    ```bash
    docker-compose down -v
    ```

## Script de Inicialização do Banco (`init-data.sh`)

Este script é montado no contêiner `postgres` e executado automaticamente pelo entrypoint do PostgreSQL na primeira vez que o contêiner é iniciado com um diretório de dados vazio. Ele garante que:

- O banco de dados especificado por `POSTGRES_DB` seja criado.
- Um usuário não-root (`POSTGRES_NON_ROOT_USER`) seja criado com a senha `POSTGRES_NON_ROOT_PASSWORD`.
- Este usuário receba todas as permissões necessárias para operar no banco de dados e no schema `public`, incluindo a capacidade de criar tabelas, sequências e funções futuras.

Isso é feito de forma idempotente, ou seja, se o banco de dados ou o usuário já existirem, o script não tentará recriá-los, evitando erros em reinicializações.
