-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: 01_estrutura.sql
-- DESCRIÇÃO: Criação do schema, tabelas e restrições
-- =========================================================

CREATE SCHEMA asas_livres;
SET search_path TO asas_livres;

-- =========================================================
-- TABELA: apartamento
-- =========================================================

CREATE TABLE apartamento (
    id_apartamento INTEGER PRIMARY KEY,
    bloco VARCHAR(5) NOT NULL,
    numero VARCHAR(4) NOT NULL,
    inicio_cobranca DATE NOT NULL,

    UNIQUE (bloco, numero),

    CHECK (
        numero ~ '^([0-9]{3}|[1-9][0-9]{3})$'
        AND numero <> '000'
    ),

    CHECK (EXTRACT(DAY FROM inicio_cobranca) = 1)
);


-- =========================================================
-- TABELA: condomino
-- =========================================================

CREATE TABLE condomino (
    id_condomino INTEGER PRIMARY KEY,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    nome_condomino VARCHAR(80) NOT NULL,
    documento_condomino VARCHAR(20) NOT NULL UNIQUE
);


-- =========================================================
-- TABELA: veiculo
-- =========================================================

CREATE TABLE veiculo (
    id_veiculo INTEGER PRIMARY KEY,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    placa VARCHAR(7) NOT NULL UNIQUE,
    modelo VARCHAR(50) NOT NULL,

    CHECK (placa ~ '^[A-Z0-9]{3,7}$')
);


-- =========================================================
-- TABELA: visitante
-- =========================================================

CREATE TABLE visitante (
    id_visitante INTEGER PRIMARY KEY,
    nome_visitante VARCHAR(80) NOT NULL,
    documento_visitante VARCHAR(20) NOT NULL UNIQUE
);


-- =========================================================
-- TABELA: visita
-- =========================================================

CREATE TABLE visita (
    id_visita INTEGER PRIMARY KEY,
    id_visitante INTEGER NOT NULL REFERENCES visitante,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    entrada TIMESTAMP NOT NULL,
    saida TIMESTAMP,

    CHECK (saida IS NULL OR saida >= entrada)
);


-- =========================================================
-- TABELA: reuniao
-- =========================================================

CREATE TABLE reuniao (
    id_reuniao INTEGER PRIMARY KEY,
    data_reuniao DATE NOT NULL UNIQUE,
    encerrada BOOLEAN NOT NULL DEFAULT FALSE,

    CHECK (EXTRACT(ISODOW FROM data_reuniao) = 1)
);


-- =========================================================
-- TABELA: presenca
-- =========================================================

CREATE TABLE presenca (
    id_reuniao INTEGER NOT NULL REFERENCES reuniao,
    id_condomino INTEGER NOT NULL REFERENCES condomino,

    PRIMARY KEY (id_reuniao, id_condomino)
);


-- =========================================================
-- TABELA: denuncia
-- =========================================================

CREATE TABLE denuncia (
    id_denuncia INTEGER PRIMARY KEY,
    id_denunciante INTEGER NOT NULL REFERENCES condomino,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    data_denuncia DATE NOT NULL,
    descricao_denuncia TEXT NOT NULL,
    id_reuniao INTEGER REFERENCES reuniao,

    UNIQUE (id_denuncia, id_reuniao),

    CHECK (BTRIM(descricao_denuncia) <> '')
);


-- =========================================================
-- TABELA: voto
-- =========================================================

CREATE TABLE voto (
    id_denuncia INTEGER NOT NULL,
    id_reuniao INTEGER NOT NULL,
    id_condomino INTEGER NOT NULL,
    favoravel BOOLEAN NOT NULL,

    PRIMARY KEY (id_denuncia, id_condomino),

    FOREIGN KEY (id_denuncia, id_reuniao)
        REFERENCES denuncia (id_denuncia, id_reuniao),

    FOREIGN KEY (id_reuniao, id_condomino)
        REFERENCES presenca (id_reuniao, id_condomino)
);


-- =========================================================
-- TABELA: tipo_multa
-- =========================================================

CREATE TABLE tipo_multa (
    id_tipo_multa INTEGER PRIMARY KEY,
    gravidade VARCHAR(10) NOT NULL UNIQUE,
    valor_multa NUMERIC(10,2) NOT NULL,

    CHECK (
        (gravidade = 'Leve' AND valor_multa = 100.00)
        OR (gravidade = 'Grave' AND valor_multa = 200.00)
        OR (gravidade = 'Gravíssima' AND valor_multa = 500.00)
    )
);


-- =========================================================
-- TABELA: multa
-- =========================================================

CREATE TABLE multa (
    id_multa INTEGER PRIMARY KEY,
    id_denuncia INTEGER NOT NULL UNIQUE REFERENCES denuncia,
    id_tipo_multa INTEGER NOT NULL REFERENCES tipo_multa,
    data_aplicacao DATE NOT NULL
);


-- =========================================================
-- TABELA: aluguel_salao
-- =========================================================

CREATE TABLE aluguel_salao (
    id_aluguel INTEGER PRIMARY KEY,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    data_reserva DATE NOT NULL,
    data_uso DATE NOT NULL UNIQUE,
    valor_aluguel NUMERIC(10,2) NOT NULL CHECK (valor_aluguel > 0),

    CHECK (data_uso >= data_reserva)
);


-- =========================================================
-- TABELA: competencia
-- =========================================================

CREATE TABLE competencia (
    mes DATE PRIMARY KEY,
    valor_taxa NUMERIC(10,2) NOT NULL CHECK (valor_taxa > 0),

    CHECK (EXTRACT(DAY FROM mes) = 1)
);


-- =========================================================
-- TABELA: boleto
-- =========================================================

CREATE TABLE boleto (
    id_boleto INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_apartamento INTEGER NOT NULL REFERENCES apartamento,
    tipo_receita VARCHAR(10) NOT NULL,
    mes DATE REFERENCES competencia,
    id_multa INTEGER UNIQUE REFERENCES multa,
    id_aluguel INTEGER UNIQUE REFERENCES aluguel_salao,
    descricao_boleto TEXT NOT NULL,
    emissao DATE NOT NULL,
    vencimento DATE NOT NULL,
    valor_boleto NUMERIC(10,2) NOT NULL CHECK (valor_boleto > 0),
    data_pagamento DATE,

    UNIQUE (id_apartamento, mes),

    CHECK (vencimento >= emissao),

    CHECK (
        data_pagamento IS NULL
        OR data_pagamento >= emissao
    ),

    CHECK (BTRIM(descricao_boleto) <> ''),

    CHECK (
        (
            tipo_receita = 'CONDOMINIO'
            AND mes IS NOT NULL
            AND id_multa IS NULL
            AND id_aluguel IS NULL
        )
        OR (
            tipo_receita = 'ALUGUEL'
            AND id_aluguel IS NOT NULL
            AND mes IS NULL
            AND id_multa IS NULL
        )
        OR (
            tipo_receita = 'EXTRA'
            AND mes IS NULL
            AND id_multa IS NULL
            AND id_aluguel IS NULL
        )
        OR (
            tipo_receita = 'MULTA'
            AND id_multa IS NOT NULL
            AND mes IS NULL
            AND id_aluguel IS NULL
        )
    ),

    CHECK (
        tipo_receita <> 'CONDOMINIO'
        OR vencimento = mes + 4
    ),

    CHECK (
        tipo_receita <> 'EXTRA'
        OR vencimento =
            (
                DATE_TRUNC('month', emissao)
                + CASE
                    WHEN EXTRACT(DAY FROM emissao) <= 10
                        THEN INTERVAL '0 months'
                    ELSE INTERVAL '1 month'
                  END
            )::DATE + 9
    )
);
