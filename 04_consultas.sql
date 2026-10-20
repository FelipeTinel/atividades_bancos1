-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: 04_consultas.sql
-- DESCRIÇÃO: Consultas finais do projeto
-- =========================================================

SET search_path TO asas_livres;


-- =========================================================
-- CONSULTA 1
-- Lista os visitantes por apartamento, com horários de
-- entrada e saída.
-- =========================================================

SELECT
    bloco AS "Bloco",
    numero AS "Apartamento",
    nome_visitante AS "Visitante",
    entrada AS "Entrada",
    saida AS "Saída"
FROM apartamento
NATURAL JOIN visita
NATURAL JOIN visitante
ORDER BY entrada, id_visita;


-- =========================================================
-- CONSULTA 2
-- Exibe, para cada apartamento:
-- - quantidade de multas;
-- - valor total das multas;
-- - valor médio das multas.
-- =========================================================

SELECT
    a.bloco AS "Bloco",
    a.numero AS "Apartamento",
    COUNT(m.id_multa) AS "Quantidade de multas",
    COALESCE(SUM(t.valor_multa), 0)::NUMERIC(10,2)
        AS "Total das multas",
    ROUND(AVG(t.valor_multa), 2)
        AS "Média das multas"
FROM apartamento a
LEFT JOIN denuncia d
    ON d.id_apartamento = a.id_apartamento
LEFT JOIN multa m
    ON m.id_denuncia = d.id_denuncia
LEFT JOIN tipo_multa t
    ON t.id_tipo_multa = m.id_tipo_multa
GROUP BY
    a.id_apartamento,
    a.bloco,
    a.numero
ORDER BY
    a.bloco,
    a.numero::INTEGER;


-- =========================================================
-- CONSULTA 3
-- Lista os apartamentos que possuem boletos com vencimento
-- anterior a 17/10/2026 e ainda não pagos.
-- =========================================================

SELECT
    a.bloco AS "Bloco",
    a.numero AS "Apartamento"
FROM apartamento a
WHERE EXISTS (
    SELECT 1
    FROM boleto b
    WHERE b.id_apartamento = a.id_apartamento
      AND b.vencimento < DATE '2026-10-17'
      AND b.data_pagamento IS NULL
)
ORDER BY
    a.bloco,
    a.numero::INTEGER;


-- =========================================================
-- CONSULTA 4
-- Lista os apartamentos cujo valor total de multas é maior
-- que o maior total registrado entre os apartamentos com
-- a maior quantidade de multas.
-- =========================================================

WITH totais AS (
    SELECT
        a.id_apartamento,
        a.bloco,
        a.numero,
        COUNT(m.id_multa) AS quantidade,
        COALESCE(SUM(t.valor_multa), 0) AS valor_total
    FROM apartamento a
    LEFT JOIN denuncia d
        ON d.id_apartamento = a.id_apartamento
    LEFT JOIN multa m
        ON m.id_denuncia = d.id_denuncia
    LEFT JOIN tipo_multa t
        ON t.id_tipo_multa = m.id_tipo_multa
    GROUP BY
        a.id_apartamento,
        a.bloco,
        a.numero
)

SELECT
    bloco AS "Bloco",
    numero AS "Apartamento",
    quantidade AS "Quantidade de multas",
    valor_total::NUMERIC(10,2) AS "Total das multas"
FROM totais
WHERE valor_total > (
    SELECT MAX(valor_total)
    FROM totais
    WHERE quantidade = (
        SELECT MAX(quantidade)
        FROM totais
    )
)
ORDER BY
    valor_total DESC,
    bloco,
    numero::INTEGER;
