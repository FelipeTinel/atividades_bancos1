# Condomínio Asas Livres 🏢

Sistema de gerenciamento de condomínio desenvolvido em **PostgreSQL**, contendo estrutura relacional completa, regras de negócio avançadas via funções e *triggers*, além de uma bateria de testes automatizados e consultas analíticas.

## 📁 Estrutura do Repositório

- **`01_estrutura.sql`**: Criação do *schema*, tabelas, chaves e restrições de validação (`CHECK`).
- **`02_regras_negocio.sql`**: Funções, *triggers* e regras globais de integridade (gestão automática de boletos, multas, reuniões e votos).
- **`03_dados.sql`**: Carga de dados iniciais e operacionais (apartamentos, condôminos, veículos, visitantes, denúncias e pagamentos).
- **`04_consultas.sql`**: Consultas analíticas e relatórios do sistema.
- **`05_testes.sql`**: Bateria automatizada de validações de integridade e regras de negócio.
- **`compose.yaml`**: Configuração do Docker Compose para subir uma instância isolada do PostgreSQL.
- **`executar_com_testes.sql`**: Script principal que executa a estrutura, carga, testes e confirma a transação caso tudo esteja válido.
- **`executar_tudo.sql`**: Script para carga completa do banco e execução das consultas principais.

## 🚀 Como Executar

### 1. Subir o Banco com Docker
Certifique-se de ter o Docker instalado e execute na raiz do projeto:
```bash
docker compose up -d
```

### 2. Executar os Scripts via `psql`
Para rodar o projeto completo junto com os testes:
```bash
psql -h localhost -p 5436 -U postgres -d asas_livres_db -f executar_com_testes.sql
```