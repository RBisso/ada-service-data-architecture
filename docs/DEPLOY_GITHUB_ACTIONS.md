# Deploy com GitHub Actions

## O que ja foi configurado

- Servidor `161.35.57.162` com Docker instalado
- Docker Compose plugin instalado
- `rsync` instalado
- Diretorio de deploy criado em `/opt/ada-service-data-architecture`
- Aplicacao publicada e validada manualmente
- Workflow criado em `.github/workflows/deploy.yml`

## Como o workflow funciona

Ao executar o workflow:

1. faz checkout do repositorio
2. cria a configuracao SSH no runner do GitHub
3. valida o acesso ao servidor
4. envia os arquivos para `/opt/ada-service-data-architecture`
5. executa `docker compose up --build -d` no servidor

## O que voce precisa fazer no GitHub

### 1. Subir o codigo para o repositorio

Garanta que estes arquivos estejam no GitHub:

- `.github/workflows/deploy.yml`
- `scripts/deploy_remote.sh`

### 2. Criar o secret da chave SSH

No repositorio do GitHub:

1. abra `Settings`
2. entre em `Secrets and variables`
3. clique em `Actions`
4. clique em `New repository secret`
5. crie o secret com o nome:

```text
DEPLOY_SSH_PRIVATE_KEY
```

6. cole no valor a chave privada que corresponde a chave publica autorizada no servidor

## Como obter a chave privada local

No seu computador, descubra qual chave esta sendo usada para acessar o servidor.

Exemplo para inspecionar:

```bash
ssh -v root@161.35.57.162
```

Normalmente o SSH vai indicar algo como:

```text
Offering public key: /Users/seu-usuario/.ssh/id_ed25519
```

Depois, copie o conteudo completo da chave privada correspondente:

```bash
cat ~/.ssh/id_ed25519
```

Se a chave usada for outra, substitua o caminho corretamente.

## Importante

- o conteudo deve incluir `-----BEGIN ... PRIVATE KEY-----`
- copie a chave inteira, incluindo a ultima linha
- nao use a chave publica `.pub`

## Como rodar o deploy manualmente pelo GitHub

Depois de criar o secret:

1. abra a aba `Actions`
2. selecione o workflow `Deploy`
3. clique em `Run workflow`
4. escolha a branch desejada
5. execute

## Quando o deploy dispara automaticamente

O workflow esta configurado para disparar em:

- `main`
- `feature/0.6`

## Como validar depois do deploy

Apos a execucao do workflow, valide:

- aplicacao: `http://161.35.57.162`
- health: `http://161.35.57.162/health`
- swagger: `http://161.35.57.162/swagger`

## Observacao importante de seguranca

Hoje o PostgreSQL esta exposto na porta `5432` do servidor.

Se voce nao precisa acessar o banco externamente, o ideal e remover o mapeamento abaixo do `docker-compose.yml`:

```yaml
ports:
  - "5432:5432"
```

Isso reduz a superficie de exposicao do servidor.
