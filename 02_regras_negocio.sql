-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: 02_regras_negocio.sql
-- DESCRIÇÃO: Funções, triggers e regras de negócio
-- =========================================================

SET search_path TO asas_livres;


-- =========================================================
-- FUNÇÃO: gerar_mensalidades
-- Gera boletos de condomínio para todas as competências
-- aplicáveis aos apartamentos.
-- =========================================================

CREATE FUNCTION gerar_mensalidades() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = asas_livres, pg_temp
AS $$
BEGIN
    INSERT INTO boleto
        (
            id_apartamento,
            tipo_receita,
            mes,
            descricao_boleto,
            emissao,
            vencimento,
            valor_boleto
        )
    SELECT
        a.id_apartamento,
        'CONDOMINIO',
        c.mes,
        'Taxa mensal de condomínio',
        c.mes,
        c.mes + 4,
        c.valor_taxa
    FROM apartamento a
    CROSS JOIN competencia c
    WHERE a.inicio_cobranca <= c.mes
      AND NOT EXISTS (
          SELECT 1
          FROM boleto b
          WHERE b.id_apartamento = a.id_apartamento
            AND b.mes = c.mes
      );

    RETURN NULL;
END;
$$;


-- =========================================================
-- TRIGGER: emitir_mensalidades
-- Ao inserir uma nova competência, gera as mensalidades.
-- =========================================================

CREATE TRIGGER emitir_mensalidades
AFTER INSERT ON competencia
FOR EACH STATEMENT
EXECUTE FUNCTION gerar_mensalidades();


-- =========================================================
-- TRIGGER: emitir_mensalidades_novo_apartamento
-- Ao inserir um novo apartamento, gera mensalidades para
-- competências já existentes às quais ele tenha direito.
-- =========================================================

CREATE TRIGGER emitir_mensalidades_novo_apartamento
AFTER INSERT ON apartamento
FOR EACH STATEMENT
EXECUTE FUNCTION gerar_mensalidades();


-- =========================================================
-- FUNÇÃO: gerar_boleto_evento
-- Gera automaticamente boletos decorrentes de multas
-- ou de aluguel do salão de festas.
-- =========================================================

CREATE FUNCTION gerar_boleto_evento() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = asas_livres, pg_temp
AS $$
BEGIN
    IF TG_TABLE_NAME = 'multa' THEN

        INSERT INTO boleto
            (
                id_apartamento,
                tipo_receita,
                id_multa,
                descricao_boleto,
                emissao,
                vencimento,
                valor_boleto
            )
        SELECT
            d.id_apartamento,
            'MULTA',
            NEW.id_multa,
            'Multa ' || t.gravidade,
            NEW.data_aplicacao,
            (
                DATE_TRUNC('month', NEW.data_aplicacao)
                + INTERVAL '1 month'
            )::DATE + 14,
            t.valor_multa
        FROM denuncia d
        CROSS JOIN tipo_multa t
        WHERE d.id_denuncia = NEW.id_denuncia
          AND t.id_tipo_multa = NEW.id_tipo_multa;

    ELSE

        INSERT INTO boleto
            (
                id_apartamento,
                tipo_receita,
                id_aluguel,
                descricao_boleto,
                emissao,
                vencimento,
                valor_boleto
            )
        VALUES
            (
                NEW.id_apartamento,
                'ALUGUEL',
                NEW.id_aluguel,
                'Aluguel do salão de festas',
                NEW.data_reserva,
                NEW.data_uso,
                NEW.valor_aluguel
            );

    END IF;

    RETURN NULL;
END;
$$;


-- =========================================================
-- TRIGGER: emitir_boleto_multa
-- =========================================================

CREATE TRIGGER emitir_boleto_multa
AFTER INSERT ON multa
FOR EACH ROW
EXECUTE FUNCTION gerar_boleto_evento();


-- =========================================================
-- TRIGGER: emitir_boleto_aluguel
-- =========================================================

CREATE TRIGGER emitir_boleto_aluguel
AFTER INSERT ON aluguel_salao
FOR EACH ROW
EXECUTE FUNCTION gerar_boleto_evento();


-- =========================================================
-- FUNÇÃO: validar_regras_condominio
-- Valida regras globais de integridade do condomínio.
-- É utilizada por constraint triggers diferíveis.
-- =========================================================

CREATE FUNCTION validar_regras_condominio() RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = asas_livres, pg_temp
AS $$
BEGIN

    -- -----------------------------------------------------
    -- Uma reunião vinculada a uma denúncia não pode ocorrer
    -- antes da data de registro da própria denúncia.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM denuncia d
        JOIN reuniao r
          ON r.id_reuniao = d.id_reuniao
        WHERE r.data_reuniao < d.data_denuncia
    ) THEN
        RAISE EXCEPTION
            'Reunião anterior ao registro da denúncia';
    END IF;


    -- -----------------------------------------------------
    -- Uma reunião encerrada precisa possuir participantes.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM reuniao r
        WHERE r.encerrada
          AND NOT EXISTS (
              SELECT 1
              FROM presenca p
              WHERE p.id_reuniao = r.id_reuniao
          )
    ) THEN
        RAISE EXCEPTION
            'Reunião encerrada sem participantes';
    END IF;


    -- -----------------------------------------------------
    -- Todos os presentes precisam votar nas denúncias
    -- vinculadas a uma reunião encerrada.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM denuncia d
        JOIN reuniao r
          ON r.id_reuniao = d.id_reuniao
        JOIN presenca p
          ON p.id_reuniao = r.id_reuniao
        WHERE r.encerrada
          AND NOT EXISTS (
              SELECT 1
              FROM voto v
              WHERE v.id_denuncia = d.id_denuncia
                AND v.id_condomino = p.id_condomino
          )
    ) THEN
        RAISE EXCEPTION
            'Faltam votos para encerrar a reunião';
    END IF;


    -- -----------------------------------------------------
    -- Uma multa exige:
    -- 1. reunião vinculada;
    -- 2. reunião encerrada;
    -- 3. aplicação na data da reunião;
    -- 4. existência de votos;
    -- 5. unanimidade favorável.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM multa m
        JOIN denuncia d
          ON d.id_denuncia = m.id_denuncia
        LEFT JOIN reuniao r
          ON r.id_reuniao = d.id_reuniao
        WHERE r.id_reuniao IS NULL
           OR NOT r.encerrada
           OR m.data_aplicacao <> r.data_reuniao
           OR NOT EXISTS (
               SELECT 1
               FROM voto v
               WHERE v.id_denuncia = d.id_denuncia
           )
           OR EXISTS (
               SELECT 1
               FROM voto v
               WHERE v.id_denuncia = d.id_denuncia
                 AND NOT v.favoravel
           )
    ) THEN
        RAISE EXCEPTION
            'Multa exige reunião encerrada e unanimidade';
    END IF;


    -- -----------------------------------------------------
    -- Todo apartamento elegível deve possuir boleto para
    -- cada competência aberta.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM apartamento a
        CROSS JOIN competencia c
        WHERE a.inicio_cobranca <= c.mes
          AND NOT EXISTS (
              SELECT 1
              FROM boleto b
              WHERE b.id_apartamento = a.id_apartamento
                AND b.mes = c.mes
          )
    ) THEN
        RAISE EXCEPTION
            'Apartamento sem boleto na competência aberta';
    END IF;


    -- -----------------------------------------------------
    -- Mensalidades devem respeitar valor, mês e emissão da
    -- competência correspondente.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM boleto b
        JOIN competencia c
          ON c.mes = b.mes
        JOIN apartamento a
          ON a.id_apartamento = b.id_apartamento
        WHERE b.valor_boleto <> c.valor_taxa
           OR b.mes < a.inicio_cobranca
           OR b.emissao <> c.mes
    ) THEN
        RAISE EXCEPTION
            'Mensalidade incompatível com a competência';
    END IF;


    -- -----------------------------------------------------
    -- Toda multa deve possuir boleto compatível.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM multa m
        JOIN denuncia d
          ON d.id_denuncia = m.id_denuncia
        JOIN tipo_multa t
          ON t.id_tipo_multa = m.id_tipo_multa
        LEFT JOIN boleto b
          ON b.id_multa = m.id_multa
        WHERE b.id_boleto IS NULL
           OR b.id_apartamento <> d.id_apartamento
           OR b.valor_boleto <> t.valor_multa
           OR b.emissao <> m.data_aplicacao
           OR b.vencimento <>
              (
                  DATE_TRUNC('month', m.data_aplicacao)
                  + INTERVAL '1 month'
              )::DATE + 14
    ) THEN
        RAISE EXCEPTION
            'Boleto de multa ausente ou incompatível';
    END IF;


    -- -----------------------------------------------------
    -- Todo aluguel de salão deve possuir boleto compatível.
    -- -----------------------------------------------------

    IF EXISTS (
        SELECT 1
        FROM aluguel_salao a
        LEFT JOIN boleto b
          ON b.id_aluguel = a.id_aluguel
        WHERE b.id_boleto IS NULL
           OR b.id_apartamento <> a.id_apartamento
           OR b.valor_boleto <> a.valor_aluguel
           OR b.emissao <> a.data_reserva
           OR b.vencimento <> a.data_uso
    ) THEN
        RAISE EXCEPTION
            'Boleto de aluguel ausente ou incompatível';
    END IF;

    RETURN NULL;
END;
$$;


-- =========================================================
-- CONSTRAINT TRIGGERS
-- Cria o mesmo trigger de validação para as tabelas cujas
-- alterações podem afetar as regras globais do sistema.
-- =========================================================

DO $$
DECLARE
    tabela TEXT;
BEGIN
    FOREACH tabela IN ARRAY ARRAY[
        'apartamento',
        'competencia',
        'reuniao',
        'presenca',
        'denuncia',
        'voto',
        'tipo_multa',
        'multa',
        'aluguel_salao',
        'boleto'
    ]
    LOOP
        EXECUTE FORMAT(
            'CREATE CONSTRAINT TRIGGER conferir_regras
             AFTER INSERT OR UPDATE OR DELETE ON %I
             DEFERRABLE INITIALLY DEFERRED
             FOR EACH ROW
             EXECUTE FUNCTION validar_regras_condominio()',
            tabela
        );
    END LOOP;
END;
$$;
