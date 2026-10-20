-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: 05_testes.sql
-- DESCRIÇÃO: Testes de integridade, regras de negócio,
--            triggers e resultados esperados.
--
-- IMPORTANTE:
-- Este arquivo deve ser executado dentro da mesma transação
-- de carga do projeto. Use executar_com_testes.sql.
-- =========================================================

SET search_path TO asas_livres;

-- Força a execução dos constraint triggers que ficaram
-- pendentes durante a carga. Se o estado final for inválido,
-- a execução para aqui.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


-- =========================================================
-- TESTE 1: quantidade de registros e distribuição de boletos
-- =========================================================

DO $$
DECLARE
    qtd INTEGER;
BEGIN
    SELECT COUNT(*) INTO qtd FROM apartamento;
    IF qtd <> 8 THEN RAISE EXCEPTION 'TESTE: esperado 8 apartamentos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM condomino;
    IF qtd <> 8 THEN RAISE EXCEPTION 'TESTE: esperado 8 condôminos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM veiculo;
    IF qtd <> 5 THEN RAISE EXCEPTION 'TESTE: esperado 5 veículos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM visitante;
    IF qtd <> 3 THEN RAISE EXCEPTION 'TESTE: esperado 3 visitantes, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM visita;
    IF qtd <> 4 THEN RAISE EXCEPTION 'TESTE: esperado 4 visitas, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM reuniao;
    IF qtd <> 3 THEN RAISE EXCEPTION 'TESTE: esperado 3 reuniões, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM presenca;
    IF qtd <> 9 THEN RAISE EXCEPTION 'TESTE: esperado 9 presenças, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM denuncia;
    IF qtd <> 11 THEN RAISE EXCEPTION 'TESTE: esperado 11 denúncias, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM voto;
    IF qtd <> 30 THEN RAISE EXCEPTION 'TESTE: esperado 30 votos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM tipo_multa;
    IF qtd <> 3 THEN RAISE EXCEPTION 'TESTE: esperado 3 tipos de multa, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM multa;
    IF qtd <> 8 THEN RAISE EXCEPTION 'TESTE: esperado 8 multas, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM competencia;
    IF qtd <> 2 THEN RAISE EXCEPTION 'TESTE: esperado 2 competências, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM aluguel_salao;
    IF qtd <> 2 THEN RAISE EXCEPTION 'TESTE: esperado 2 aluguéis, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto;
    IF qtd <> 34 THEN RAISE EXCEPTION 'TESTE: esperado 34 boletos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE tipo_receita = 'CONDOMINIO';
    IF qtd <> 16 THEN RAISE EXCEPTION 'TESTE: esperado 16 boletos de condomínio, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE tipo_receita = 'MULTA';
    IF qtd <> 8 THEN RAISE EXCEPTION 'TESTE: esperado 8 boletos de multa, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE tipo_receita = 'ALUGUEL';
    IF qtd <> 2 THEN RAISE EXCEPTION 'TESTE: esperado 2 boletos de aluguel, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE tipo_receita = 'EXTRA';
    IF qtd <> 8 THEN RAISE EXCEPTION 'TESTE: esperado 8 boletos extras, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE data_pagamento IS NOT NULL;
    IF qtd <> 21 THEN RAISE EXCEPTION 'TESTE: esperado 21 boletos pagos, obtido %', qtd; END IF;

    SELECT COUNT(*) INTO qtd FROM boleto WHERE data_pagamento IS NULL;
    IF qtd <> 13 THEN RAISE EXCEPTION 'TESTE: esperado 13 boletos pendentes, obtido %', qtd; END IF;
END;
$$;


-- =========================================================
-- TESTE 2: resultados das quatro consultas finais
-- =========================================================

DO $$
DECLARE
    diferencas INTEGER;
    apartamentos INTEGER[];
BEGIN
    -- Consulta 1: conjunto exato de visitas esperado.
    WITH atual AS (
        SELECT bloco, numero, nome_visitante, entrada, saida
        FROM apartamento
        NATURAL JOIN visita
        NATURAL JOIN visitante
    ),
    esperado(bloco, numero, nome_visitante, entrada, saida) AS (
        VALUES
            ('A'::VARCHAR, '007'::VARCHAR, 'João Suco Cleber'::VARCHAR,
             TIMESTAMP '2026-10-01 14:00', TIMESTAMP '2026-10-01 17:00'),
            ('B', '303', 'Enkidu',
             TIMESTAMP '2026-10-02 10:00', TIMESTAMP '2026-10-02 11:30'),
            ('A', '1001', 'João Suco Cleber',
             TIMESTAMP '2026-10-03 18:00', TIMESTAMP '2026-10-03 20:00'),
            ('A', '402', 'Blanski',
             TIMESTAMP '2026-10-04 09:00', NULL::TIMESTAMP)
    ),
    diff AS (
        (SELECT * FROM atual EXCEPT SELECT * FROM esperado)
        UNION ALL
        (SELECT * FROM esperado EXCEPT SELECT * FROM atual)
    )
    SELECT COUNT(*) INTO diferencas FROM diff;

    IF diferencas <> 0 THEN
        RAISE EXCEPTION 'TESTE: consulta 1 diverge do resultado esperado';
    END IF;

    -- Consulta 2: agregações exatas de multas por apartamento.
    WITH atual AS (
        SELECT
            a.id_apartamento,
            COUNT(m.id_multa)::INTEGER AS quantidade,
            COALESCE(SUM(t.valor_multa), 0)::NUMERIC(10,2) AS total,
            ROUND(AVG(t.valor_multa), 2)::NUMERIC(10,2) AS media
        FROM apartamento a
        LEFT JOIN denuncia d ON d.id_apartamento = a.id_apartamento
        LEFT JOIN multa m ON m.id_denuncia = d.id_denuncia
        LEFT JOIN tipo_multa t ON t.id_tipo_multa = m.id_tipo_multa
        GROUP BY a.id_apartamento
    ),
    esperado(id_apartamento, quantidade, total, media) AS (
        VALUES
            (1, 4, 400.00::NUMERIC(10,2), 100.00::NUMERIC(10,2)),
            (2, 2, 1000.00::NUMERIC(10,2), 500.00::NUMERIC(10,2)),
            (3, 1, 500.00::NUMERIC(10,2), 500.00::NUMERIC(10,2)),
            (4, 1, 200.00::NUMERIC(10,2), 200.00::NUMERIC(10,2)),
            (5, 0, 0.00::NUMERIC(10,2), NULL::NUMERIC(10,2)),
            (6, 0, 0.00::NUMERIC(10,2), NULL::NUMERIC(10,2)),
            (7, 0, 0.00::NUMERIC(10,2), NULL::NUMERIC(10,2)),
            (8, 0, 0.00::NUMERIC(10,2), NULL::NUMERIC(10,2))
    ),
    diff AS (
        (SELECT * FROM atual EXCEPT SELECT * FROM esperado)
        UNION ALL
        (SELECT * FROM esperado EXCEPT SELECT * FROM atual)
    )
    SELECT COUNT(*) INTO diferencas FROM diff;

    IF diferencas <> 0 THEN
        RAISE EXCEPTION 'TESTE: consulta 2 diverge do resultado esperado';
    END IF;

    -- Consulta 3: apartamentos inadimplentes na data de corte.
    SELECT array_agg(a.id_apartamento ORDER BY a.id_apartamento)
    INTO apartamentos
    FROM apartamento a
    WHERE EXISTS (
        SELECT 1
        FROM boleto b
        WHERE b.id_apartamento = a.id_apartamento
          AND b.vencimento < DATE '2026-10-17'
          AND b.data_pagamento IS NULL
    );

    IF apartamentos IS DISTINCT FROM ARRAY[1,2,4,5,6,7,8] THEN
        RAISE EXCEPTION 'TESTE: consulta 3 retornou apartamentos inesperados: %', apartamentos;
    END IF;

    -- Consulta 4: apartamentos cujo total supera o maior total
    -- entre aqueles que têm a maior quantidade de multas.
    WITH totais AS (
        SELECT
            a.id_apartamento,
            COUNT(m.id_multa) AS quantidade,
            COALESCE(SUM(t.valor_multa), 0) AS valor_total
        FROM apartamento a
        LEFT JOIN denuncia d ON d.id_apartamento = a.id_apartamento
        LEFT JOIN multa m ON m.id_denuncia = d.id_denuncia
        LEFT JOIN tipo_multa t ON t.id_tipo_multa = m.id_tipo_multa
        GROUP BY a.id_apartamento
    )
    SELECT array_agg(id_apartamento ORDER BY valor_total DESC, id_apartamento)
    INTO apartamentos
    FROM totais
    WHERE valor_total > (
        SELECT MAX(valor_total)
        FROM totais
        WHERE quantidade = (SELECT MAX(quantidade) FROM totais)
    );

    IF apartamentos IS DISTINCT FROM ARRAY[2,3] THEN
        RAISE EXCEPTION 'TESTE: consulta 4 retornou apartamentos inesperados: %', apartamentos;
    END IF;
END;
$$;


-- =========================================================
-- TESTE 3: trigger de mensalidade ao inserir apartamento
-- =========================================================

SAVEPOINT teste_trigger_apartamento;

INSERT INTO apartamento
    (id_apartamento, bloco, numero, inicio_cobranca)
VALUES
    (99, 'Z', '999', '2026-09-01');

DO $$
DECLARE
    qtd INTEGER;
BEGIN
    SELECT COUNT(*) INTO qtd
    FROM boleto
    WHERE id_apartamento = 99
      AND tipo_receita = 'CONDOMINIO';

    IF qtd <> 2 THEN
        RAISE EXCEPTION 'TESTE: novo apartamento deveria gerar 2 mensalidades, gerou %', qtd;
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT teste_trigger_apartamento;
RELEASE SAVEPOINT teste_trigger_apartamento;


-- =========================================================
-- TESTE 4: trigger de mensalidade ao inserir competência
-- =========================================================

SAVEPOINT teste_trigger_competencia;

INSERT INTO competencia (mes, valor_taxa)
VALUES (DATE '2026-11-01', 360.00);

DO $$
DECLARE
    qtd INTEGER;
BEGIN
    SELECT COUNT(*) INTO qtd
    FROM boleto
    WHERE mes = DATE '2026-11-01'
      AND tipo_receita = 'CONDOMINIO';

    IF qtd <> 8 THEN
        RAISE EXCEPTION 'TESTE: nova competência deveria gerar 8 mensalidades, gerou %', qtd;
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT teste_trigger_competencia;
RELEASE SAVEPOINT teste_trigger_competencia;


-- =========================================================
-- TESTE 5: trigger de boleto de multa
-- =========================================================

SAVEPOINT teste_trigger_multa;

INSERT INTO denuncia
    (id_denuncia, id_denunciante, id_apartamento,
     data_denuncia, descricao_denuncia, id_reuniao)
VALUES
    (99, 5, 8, DATE '2026-09-20', 'Denúncia temporária de teste', 3);

INSERT INTO voto (id_denuncia, id_reuniao, id_condomino, favoravel)
SELECT 99, 3, p.id_condomino, TRUE
FROM presenca p
WHERE p.id_reuniao = 3;

INSERT INTO multa
    (id_multa, id_denuncia, id_tipo_multa, data_aplicacao)
VALUES
    (99, 99, 2, DATE '2026-09-21');

DO $$
DECLARE
    qtd INTEGER;
BEGIN
    SELECT COUNT(*) INTO qtd
    FROM boleto
    WHERE id_multa = 99
      AND tipo_receita = 'MULTA'
      AND id_apartamento = 8
      AND valor_boleto = 200.00
      AND emissao = DATE '2026-09-21'
      AND vencimento = DATE '2026-10-15';

    IF qtd <> 1 THEN
        RAISE EXCEPTION 'TESTE: trigger de multa não gerou boleto compatível';
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT teste_trigger_multa;
RELEASE SAVEPOINT teste_trigger_multa;


-- =========================================================
-- TESTE 6: trigger de boleto de aluguel
-- =========================================================

SAVEPOINT teste_trigger_aluguel;

INSERT INTO aluguel_salao
    (id_aluguel, id_apartamento, data_reserva, data_uso, valor_aluguel)
VALUES
    (99, 8, DATE '2026-10-20', DATE '2026-11-20', 250.00);

DO $$
DECLARE
    qtd INTEGER;
BEGIN
    SELECT COUNT(*) INTO qtd
    FROM boleto
    WHERE id_aluguel = 99
      AND tipo_receita = 'ALUGUEL'
      AND id_apartamento = 8
      AND valor_boleto = 250.00
      AND emissao = DATE '2026-10-20'
      AND vencimento = DATE '2026-11-20';

    IF qtd <> 1 THEN
        RAISE EXCEPTION 'TESTE: trigger de aluguel não gerou boleto compatível';
    END IF;
END;
$$;

ROLLBACK TO SAVEPOINT teste_trigger_aluguel;
RELEASE SAVEPOINT teste_trigger_aluguel;


-- =========================================================
-- TESTES 7 A 14: constraint triggers devem rejeitar estados
-- inválidos. Cada bloco usa uma subtransação implícita do
-- PL/pgSQL; ao capturar a exceção esperada, a alteração de
-- teste é desfeita automaticamente.
-- =========================================================

-- 7. Reunião anterior ao registro da denúncia.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        INSERT INTO denuncia
            (id_denuncia, id_denunciante, id_apartamento,
             data_denuncia, descricao_denuncia, id_reuniao)
        VALUES
            (99, 5, 8, DATE '2026-09-08', 'Teste inválido', 1);

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Reunião anterior ao registro da denúncia' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: reunião anterior à denúncia não foi rejeitada';
    END IF;
END;
$$;

-- 8. Reunião encerrada sem participantes.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        INSERT INTO reuniao (id_reuniao, data_reuniao, encerrada)
        VALUES (99, DATE '2026-10-26', TRUE);

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Reunião encerrada sem participantes' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: reunião encerrada sem participantes não foi rejeitada';
    END IF;
END;
$$;

-- 9. Reunião encerrada com voto ausente.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        INSERT INTO denuncia
            (id_denuncia, id_denunciante, id_apartamento,
             data_denuncia, descricao_denuncia, id_reuniao)
        VALUES
            (99, 5, 8, DATE '2026-09-20', 'Teste sem votos', 3);

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Faltam votos para encerrar a reunião' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: ausência de votos não foi rejeitada';
    END IF;
END;
$$;

-- 10. Multa sem unanimidade.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        INSERT INTO multa
            (id_multa, id_denuncia, id_tipo_multa, data_aplicacao)
        VALUES
            (99, 8, 1, DATE '2026-09-14');

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Multa exige reunião encerrada e unanimidade' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: multa sem unanimidade não foi rejeitada';
    END IF;
END;
$$;

-- 11. Mensalidade ausente.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        DELETE FROM boleto
        WHERE id_apartamento = 1
          AND mes = DATE '2026-10-01';

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Apartamento sem boleto na competência aberta' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: mensalidade ausente não foi rejeitada';
    END IF;
END;
$$;

-- 12. Mensalidade incompatível com a competência.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        UPDATE boleto
        SET valor_boleto = 999.00
        WHERE id_apartamento = 1
          AND mes = DATE '2026-10-01';

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Mensalidade incompatível com a competência' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: mensalidade incompatível não foi rejeitada';
    END IF;
END;
$$;

-- 13. Boleto de multa ausente.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        DELETE FROM boleto
        WHERE id_multa = 1;

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Boleto de multa ausente ou incompatível' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: ausência do boleto de multa não foi rejeitada';
    END IF;
END;
$$;

-- 14. Boleto de aluguel ausente.
DO $$
DECLARE
    detectado BOOLEAN := FALSE;
BEGIN
    BEGIN
        DELETE FROM boleto
        WHERE id_aluguel = 1;

        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Boleto de aluguel ausente ou incompatível' THEN
            detectado := TRUE;
        ELSE
            RAISE;
        END IF;
    END;

    SET CONSTRAINTS ALL DEFERRED;

    IF NOT detectado THEN
        RAISE EXCEPTION 'TESTE: ausência do boleto de aluguel não foi rejeitada';
    END IF;
END;
$$;

-- Nenhum teste deve deixar alterações pendentes.
SET CONSTRAINTS ALL IMMEDIATE;

-- Sequências do PostgreSQL não são revertidas por SAVEPOINT/subtransação.
-- Os testes de triggers geram boletos temporários, então restauramos a
-- sequência da coluna identity para o maior id realmente persistente.
SELECT setval(
    pg_get_serial_sequence('asas_livres.boleto', 'id_boleto')::regclass,
    (SELECT MAX(id_boleto) FROM boleto),
    TRUE
);

DO $$
BEGIN
    RAISE NOTICE 'Todos os testes do projeto Asas Livres foram concluídos.';
END;
$$;
