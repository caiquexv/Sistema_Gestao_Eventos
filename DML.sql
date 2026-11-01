-- ============================================================
-- Sistema de Gestao de Eventos e Espacos
-- Dados de demonstracao (DML)
-- Executar depois da criacao do banco (DDL).
-- ============================================================

-- Series
INSERT INTO serie (id, nome) VALUES
  (1, 'Semana da Computacao');

-- Organizacoes
INSERT INTO organizacao (id, nome, tipo) VALUES
  (1, 'Universidade de Sao Paulo', 'universidade'),
  (2, 'TechEventos Ltda', 'empresa');

-- Pessoas
INSERT INTO pessoa (id, nome, email) VALUES
  (1,  'Ana Souza',     'ana@exemplo.com'),
  (2,  'Bruno Lima',    'bruno@exemplo.com'),
  (3,  'Carla Dias',    'carla@exemplo.com'),
  (4,  'Diego Alves',   'diego@exemplo.com'),
  (5,  'Elena Rocha',   'elena@exemplo.com'),
  (6,  'Felipe Nunes',  'felipe@exemplo.com'),
  (7,  'Gabriela Melo', 'gabriela@exemplo.com'),
  (8,  'Hugo Pires',    'hugo@exemplo.com'),
  (9,  'Isabela Reis',  'isabela@exemplo.com'),
  (10, 'Joao Castro',   'joao@exemplo.com');

-- Espacos
INSERT INTO espaco (id, nome, capacidade) VALUES
  (1, 'Auditorio Principal', 200),
  (2, 'Sala A', 2),
  (3, 'Laboratorio 1', 30),
  (4, 'Sala B', 50),
  (5, 'Espaco Expo', 100);

-- Recursos
INSERT INTO recurso (id, nome) VALUES
  (1, 'projetor'),
  (2, 'computadores'),
  (3, 'audio'),
  (4, 'internet');

-- Recursos de cada espaco
INSERT INTO espaco_recurso (espaco_id, recurso_id) VALUES
  (1,1),(1,3),(1,4),
  (2,1),
  (3,1),(3,2),(3,4),
  (4,1),(4,4),
  (5,4);

-- Eventos (o evento 2 e uma edicao recorrente em promocao conjunta)
INSERT INTO evento (id, serie_id, nome, data_inicio, data_fim) VALUES
  (1, 1,    'Semana da Computacao 2025', DATE '2025-09-15', DATE '2025-09-19'),
  (2, 1,    'Semana da Computacao 2026', DATE '2026-09-14', DATE '2026-09-18'),
  (3, NULL, 'Feira de Tecnologia 2026',  DATE '2026-10-05', DATE '2026-10-06');

-- Promocao por pessoas
INSERT INTO promocao_pessoa (evento_id, pessoa_id) VALUES
  (2, 1),
  (3, 2);

-- Promocao por organizacoes (o evento 2 e promovido por duas organizacoes)
INSERT INTO promocao_organizacao (evento_id, organizacao_id) VALUES
  (1, 1),
  (2, 1),
  (2, 2),
  (3, 2);

-- Atividades
INSERT INTO atividade (id, evento_id, titulo, descricao, tipo) VALUES
  (1, 2, 'Workshop de PostgreSQL',  'Pratica de modelagem e SQL', 'workshop'),
  (2, 2, 'Palestra de Abertura',    'Sessao inaugural do evento', 'palestra'),
  (3, 2, 'Minicurso de Python',     'Introducao a linguagem',     'minicurso'),
  (4, 2, 'Painel de Carreira',      'Conversa com profissionais', 'painel'),
  (5, 1, 'Palestra de IA',          'Panorama historico',         'palestra'),
  (6, 3, 'Apresentacao de Startups','Rodada de pitches',          'apresentacao');

-- Papeis ligados ao evento (organizadores)
INSERT INTO papel_evento (pessoa_id, evento_id, papel) VALUES
  (1,  2, 'organizador'),
  (10, 2, 'coordenador');

-- Papeis ligados a atividade (palestrantes, instrutores e mediadores)
INSERT INTO papel_atividade (pessoa_id, atividade_id, papel) VALUES
  (2, 1, 'instrutor'),
  (3, 2, 'palestrante'),
  (4, 3, 'instrutor'),
  (5, 4, 'mediador'),
  (1, 5, 'palestrante');

-- Inscricoes no evento
INSERT INTO inscricao_evento (pessoa_id, evento_id, status) VALUES
  (1,  2, 'confirmada'),
  (2,  2, 'confirmada'),
  (3,  2, 'confirmada'),
  (4,  2, 'confirmada'),
  (5,  2, 'confirmada'),
  (6,  2, 'confirmada'),
  (7,  2, 'confirmada'),
  (8,  2, 'confirmada'),
  (9,  2, 'cancelada'),
  (10, 2, 'confirmada'),
  (1,  1, 'confirmada'),
  (2,  1, 'confirmada'),
  (3,  1, 'confirmada'),
  (2,  3, 'confirmada'),
  (4,  3, 'confirmada');

-- Sessoes (duas do Workshop, uma geral de abertura, minicurso em sala pequena, etc.)
INSERT INTO sessao (id, atividade_id, espaco_id, data, hora_inicio, hora_fim, requer_inscricao, limite_vagas) VALUES
  (1, 1, 3, DATE '2026-09-15', TIME '09:00', TIME '12:00', true,  2),
  (2, 1, 3, DATE '2026-09-15', TIME '14:00', TIME '17:00', true,  30),
  (3, 2, 1, DATE '2026-09-14', TIME '19:00', TIME '20:30', false, NULL),
  (4, 3, 2, DATE '2026-09-16', TIME '09:00', TIME '11:00', true,  NULL),
  (5, 4, 4, DATE '2026-09-17', TIME '16:00', TIME '18:00', true,  10),
  (6, 3, 3, DATE '2026-09-16', TIME '14:00', TIME '16:00', true,  30),
  (7, 5, 1, DATE '2025-09-16', TIME '10:00', TIME '11:30', false, NULL),
  (8, 6, 1, DATE '2026-10-05', TIME '09:00', TIME '12:00', false, NULL);

-- Inscricoes em sessoes restritas
-- (Ana esta inscrita em todas as sessoes restritas do evento 2)
INSERT INTO inscricao_sessao (pessoa_id, sessao_id, status) VALUES
  (1, 1, 'confirmada'),
  (2, 1, 'confirmada'),
  (1, 2, 'confirmada'),
  (3, 2, 'confirmada'),
  (4, 2, 'confirmada'),
  (5, 2, 'confirmada'),
  (1, 4, 'confirmada'),
  (6, 4, 'confirmada'),
  (1, 5, 'confirmada'),
  (2, 5, 'confirmada'),
  (3, 5, 'confirmada'),
  (4, 5, 'confirmada'),
  (5, 5, 'confirmada'),
  (8, 5, 'cancelada'),
  (1, 6, 'confirmada'),
  (7, 6, 'confirmada');

-- Alteracoes de programacao que geram historico via trigger
UPDATE sessao SET hora_inicio = TIME '15:00', hora_fim = TIME '18:00' WHERE id = 2;
UPDATE sessao SET espaco_id = 1 WHERE id = 5;

-- Sincroniza as sequencias de identidade com os maiores ids inseridos manualmente
SELECT setval(pg_get_serial_sequence('serie','id'),            (SELECT max(id) FROM serie));
SELECT setval(pg_get_serial_sequence('organizacao','id'),      (SELECT max(id) FROM organizacao));
SELECT setval(pg_get_serial_sequence('pessoa','id'),           (SELECT max(id) FROM pessoa));
SELECT setval(pg_get_serial_sequence('espaco','id'),           (SELECT max(id) FROM espaco));
SELECT setval(pg_get_serial_sequence('recurso','id'),          (SELECT max(id) FROM recurso));
SELECT setval(pg_get_serial_sequence('evento','id'),           (SELECT max(id) FROM evento));
SELECT setval(pg_get_serial_sequence('atividade','id'),        (SELECT max(id) FROM atividade));
SELECT setval(pg_get_serial_sequence('sessao','id'),           (SELECT max(id) FROM sessao));
SELECT setval(pg_get_serial_sequence('historico_sessao','id'), (SELECT max(id) FROM historico_sessao));
