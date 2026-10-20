-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: executar_com_testes.sql
-- DESCRIÇÃO: Monta o banco, executa os testes e somente
--            confirma a transação se tudo estiver válido.
-- =========================================================

\set ON_ERROR_STOP on

BEGIN ISOLATION LEVEL SERIALIZABLE;

\ir 01_estrutura.sql
\ir 02_regras_negocio.sql
\ir 03_dados.sql
\ir 05_testes.sql

COMMIT;

\ir 04_consultas.sql
