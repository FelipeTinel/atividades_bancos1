-- =========================================================
-- PROJETO: Condomínio Asas Livres
-- ARQUIVO: 03_dados.sql
-- DESCRIÇÃO: Carga de dados iniciais, dados operacionais
--            e atualizações de pagamentos
-- =========================================================

SET search_path TO asas_livres;


-- =========================================================
-- DADOS INICIAIS: apartamentos
-- =========================================================

INSERT INTO apartamento
    (id_apartamento, bloco, numero, inicio_cobranca)
VALUES
    (1, 'A', '007', '2026-09-01'),
    (2, 'A', '1001', '2026-09-01'),
    (3, 'A', '402', '2026-09-01'),
    (4, 'A', '904', '2026-09-01'),
    (5, 'B', '101', '2026-09-01'),
    (6, 'B', '303', '2026-09-01'),
    (7, 'A', '503', '2026-09-01'),
    (8, 'B', '1204', '2026-09-01');


-- =========================================================
-- DADOS INICIAIS: condôminos
-- =========================================================

INSERT INTO condomino
    (id_condomino, id_apartamento, nome_condomino, documento_condomino)
VALUES
    (1, 1, 'Ana Bolizante', 'MOR001'),
    (2, 2, 'Mestre dos Magos', 'MOR002'),
    (3, 3, 'Jan Derson', 'MOR003'),
    (4, 4, 'Tineldroid', 'MOR004'),
    (5, 7, 'Matuê', 'MOR005'),
    (6, 5, 'Alguém Líryo', 'MOR006'),
    (7, 6, 'Gilgamesh', 'MOR007'),
    (8, 8, 'Ventilador Silva', 'MOR008');


-- =========================================================
-- DADOS INICIAIS: veículos
-- =========================================================

INSERT INTO veiculo
    (id_veiculo, id_apartamento, placa, modelo)
VALUES
    (1, 1, 'ZZZ0Z00', 'Tesla Roadster'),
    (2, 3, 'KLJ4S36', 'Batmóvel'),
    (3, 5, 'GUV9O67', 'Opala'),
    (4, 4, 'HXH', 'Hot Wheels'),
    (5, 1, 'SFC8A35', 'Fusca');


-- =========================================================
-- DADOS INICIAIS: visitantes
-- =========================================================

INSERT INTO visitante
    (id_visitante, nome_visitante, documento_visitante)
VALUES
    (1, 'João Suco Cleber', 'VIS001'),
    (2, 'Enkidu', 'VIS002'),
    (3, 'Blanski', 'VIS003');


-- =========================================================
-- DADOS OPERACIONAIS: visitas
-- =========================================================

INSERT INTO visita
    (id_visita, id_visitante, id_apartamento, entrada, saida)
VALUES
    (1, 1, 1, '2026-10-01 14:00', '2026-10-01 17:00'),
    (2, 2, 6, '2026-10-02 10:00', '2026-10-02 11:30'),
    (3, 1, 2, '2026-10-03 18:00', '2026-10-03 20:00'),
    (4, 3, 3, '2026-10-04 09:00', NULL);


-- =========================================================
-- DADOS OPERACIONAIS: reuniões
-- =========================================================

INSERT INTO reuniao
    (id_reuniao, data_reuniao)
VALUES
    (1, '2026-09-07'),
    (2, '2026-09-14'),
    (3, '2026-09-21');


-- =========================================================
-- DADOS OPERACIONAIS: presenças
-- =========================================================

INSERT INTO presenca
    (id_reuniao, id_condomino)
SELECT
    r.id_reuniao,
    c.id_condomino
FROM reuniao r
CROSS JOIN condomino c
WHERE c.id_condomino IN (5, 6, 7);


-- =========================================================
-- DADOS OPERACIONAIS: denúncias
-- =========================================================

INSERT INTO denuncia
    (
        id_denuncia,
        id_denunciante,
        id_apartamento,
        data_denuncia,
        descricao_denuncia,
        id_reuniao
    )
VALUES
    (1, 5, 1, '2026-09-01', 'Barulho após o horário permitido', 1),
    (2, 6, 1, '2026-09-02', 'Lixo fora do local de coleta', 1),
    (3, 7, 2, '2026-09-03', 'Dano ao portão da garagem', 1),
    (4, 5, 3, '2026-09-04', 'Dano ao elevador', 1),
    (5, 6, 1, '2026-09-08', 'Objeto deixado no corredor', 2),
    (6, 7, 2, '2026-09-09', 'Uso indevido de área restrita', 2),
    (7, 5, 4, '2026-09-10', 'Estacionamento em vaga alheia', 2),
    (8, 6, 5, '2026-09-11', 'Ruído sem comprovação', 2),
    (9, 7, 1, '2026-09-15', 'Descarte irregular de material', 3),
    (10, 5, 6, '2026-09-16', 'Barulho em horário permitido', 3),
    (11, 6, 3, '2026-09-22', 'Uso de equipamento fora do horário', NULL);


-- =========================================================
-- DADOS OPERACIONAIS: votos
-- =========================================================

INSERT INTO voto
    (id_denuncia, id_reuniao, id_condomino, favoravel)
SELECT
    d.id_denuncia,
    d.id_reuniao,
    p.id_condomino,
    NOT (
        d.id_denuncia IN (8, 10)
        AND p.id_condomino = 7
    )
FROM denuncia d
JOIN presenca p
  ON p.id_reuniao = d.id_reuniao;


-- =========================================================
-- ENCERRAMENTO DAS REUNIÕES
-- =========================================================

UPDATE reuniao
SET encerrada = TRUE;


-- =========================================================
-- DADOS DE REFERÊNCIA: tipos de multa
-- =========================================================

INSERT INTO tipo_multa
    (id_tipo_multa, gravidade, valor_multa)
VALUES
    (1, 'Leve', 100.00),
    (2, 'Grave', 200.00),
    (3, 'Gravíssima', 500.00);


-- =========================================================
-- DADOS OPERACIONAIS: multas
-- A inserção dispara automaticamente a geração dos boletos.
-- =========================================================

INSERT INTO multa
    (id_multa, id_denuncia, id_tipo_multa, data_aplicacao)
VALUES
    (1, 1, 1, '2026-09-07'),
    (2, 2, 1, '2026-09-07'),
    (3, 3, 3, '2026-09-07'),
    (4, 4, 3, '2026-09-07'),
    (5, 5, 1, '2026-09-14'),
    (6, 6, 3, '2026-09-14'),
    (7, 7, 2, '2026-09-14'),
    (8, 9, 1, '2026-09-21');


-- =========================================================
-- DADOS OPERACIONAIS: competências
-- A inserção dispara automaticamente a geração das
-- mensalidades dos apartamentos elegíveis.
-- =========================================================

INSERT INTO competencia
    (mes, valor_taxa)
VALUES
    ('2026-09-01', 350.00),
    ('2026-10-01', 350.00);


-- =========================================================
-- DADOS OPERACIONAIS: aluguel do salão
-- A inserção dispara automaticamente a geração dos boletos.
-- =========================================================

INSERT INTO aluguel_salao
    (
        id_aluguel,
        id_apartamento,
        data_reserva,
        data_uso,
        valor_aluguel
    )
VALUES
    (1, 2, '2026-10-01', '2026-10-03', 250.00),
    (2, 5, '2026-10-02', '2026-10-10', 250.00);


-- =========================================================
-- DADOS OPERACIONAIS: cobrança extraordinária
-- =========================================================

INSERT INTO boleto
    (
        id_apartamento,
        tipo_receita,
        descricao_boleto,
        emissao,
        vencimento,
        valor_boleto
    )
SELECT
    id_apartamento,
    'EXTRA',
    'Reparo da bomba de água',
    DATE '2026-10-02',
    DATE '2026-10-10',
    80.00
FROM apartamento
ORDER BY id_apartamento;


-- =========================================================
-- ATUALIZAÇÕES: pagamentos das mensalidades de setembro
-- =========================================================

UPDATE boleto
SET data_pagamento = DATE '2026-09-05'
WHERE tipo_receita = 'CONDOMINIO'
  AND mes = DATE '2026-09-01';


-- =========================================================
-- ATUALIZAÇÕES: pagamentos parciais das mensalidades
-- de outubro
-- =========================================================

UPDATE boleto
SET data_pagamento = DATE '2026-10-05'
WHERE tipo_receita = 'CONDOMINIO'
  AND mes = DATE '2026-10-01'
  AND id_apartamento IN (1, 2, 3, 5);


-- =========================================================
-- ATUALIZAÇÕES: pagamentos da cobrança extraordinária
-- =========================================================

UPDATE boleto
SET data_pagamento = DATE '2026-10-10'
WHERE tipo_receita = 'EXTRA'
  AND id_apartamento IN (1, 2, 3);


-- =========================================================
-- ATUALIZAÇÕES: pagamentos dos aluguéis
-- =========================================================

UPDATE boleto
SET data_pagamento = vencimento
WHERE tipo_receita = 'ALUGUEL';


-- =========================================================
-- ATUALIZAÇÕES: pagamentos de multas
-- =========================================================

UPDATE boleto
SET data_pagamento = DATE '2026-10-15'
WHERE tipo_receita = 'MULTA'
  AND id_multa IN (1, 3, 4, 7);

