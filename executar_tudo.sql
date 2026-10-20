-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: executar_tudo.sql
-- DESCRIÇÃO: Executa todos os arquivos do projeto na ordem
--            correta.
--
-- O comando \ir resolve os caminhos relativamente à pasta
-- deste próprio arquivo, tornando a execução mais robusta.
-- =========================================================

\set ON_ERROR_STOP on

BEGIN ISOLATION LEVEL SERIALIZABLE;

\ir 01_estrutura.sql
\ir 02_regras_negocio.sql
\ir 03_dados.sql

COMMIT;

\ir 04_consultas.sql
