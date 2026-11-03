-- CARGA INICIAL: dados ficticios, compativeis com o MER final.
-- Execute o bloco inteiro, uma unica vez, com as 21 tabelas vazias.
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
SET LOCAL search_path = public;

-- 0. Protecao contra repeticao: nenhum dado existente e apagado.
DO $$
DECLARE t text; ocupada boolean;
BEGIN
  PERFORM pg_advisory_xact_lock(6400,202602);
  FOREACH t IN ARRAY ARRAY['serie','agente','pessoa','empresa','organizacao',
    'agente_telefone','espaco','recurso','evento','promocao_evento','atividade',
    'sessao','evento_espaco','espaco_recurso','sessao_recurso_necessario',
    'alocacao','alocacao_recurso','papel_evento','papel_sessao',
    'inscricao_evento','inscricao_sessao']
  LOOP
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I)',t) INTO ocupada;
    IF ocupada THEN
      RAISE EXCEPTION 'Carga inicial recusada: tabela % ja tem dados.',t;
    END IF;
  END LOOP;
END $$;

-- 1. Oitenta pessoas, quatro empresas e quatro organizacoes.
INSERT INTO agente(agente_id,email)
SELECT n,'pessoa'||lpad(n::text,3,'0')||'@example.test'
FROM generate_series(1,80) AS g(n);
INSERT INTO pessoa(agente_id,nome,cpf)
SELECT n,
  (ARRAY['Ana','Bruno','Carla','Diego','Elena','Felipe','Gabriela',
         'Hugo','Isabela','Joao'])[((n-1)%10)+1]||' '||
  (ARRAY['Souza','Lima','Dias','Alves','Rocha','Nunes','Melo','Pires'])[((n-1)/10)+1],
  CASE WHEN n%5=0 THEN NULL ELSE (90000000000::bigint+n)::text END
FROM generate_series(1,80) AS g(n);
INSERT INTO agente(agente_id,email)
SELECT 1000+n,'empresa'||n||'@example.test' FROM generate_series(1,4) AS g(n)
UNION ALL
SELECT 2000+n,'organizacao'||n||'@example.test' FROM generate_series(1,4) AS g(n);
INSERT INTO empresa(agente_id,nome,cnpj) VALUES
 (1001,'Aurora Tecnologia Exemplo','99000000000001'),
 (1002,'Horizonte Dados Exemplo','99000000000002'),
 (1003,'Ponte Educacao Exemplo','99000000000003'),
 (1004,'Conexao Eventos Exemplo',NULL);
INSERT INTO organizacao(agente_id,nome_org) VALUES
 (2001,'Instituto Academico Exemplo'),(2002,'Associacao de Computacao Exemplo'),
 (2003,'Coletivo Inovacao Exemplo'),(2004,'Liga Cientifica Exemplo');
INSERT INTO agente_telefone(agente_id,telefone)
SELECT agente_id,'+55 (00) 90000-'||lpad(agente_id::text,4,'0')
FROM agente WHERE agente_id<=60 OR agente_id>=1001;
INSERT INTO agente_telefone(agente_id,telefone)
SELECT n,'+55 (00) 80000-'||lpad(n::text,4,'0') FROM generate_series(1,10) AS g(n);

-- 2. Espacos, recursos e quantidades disponiveis (inclusive zero).
INSERT INTO espaco(espaco_id,nome,tipo,capacidade,rua,cep,numero) VALUES
 (1,'Auditorio Central','auditorio',200,'Rua Academica','00000001','100'),
 (2,'Sala A','sala',30,'Rua Academica','00000001','102'),
 (3,'Laboratorio de Dados','laboratorio',20,'Rua dos Estudos','00000002','200'),
 (4,'Laboratorio de Python','laboratorio',12,'Rua dos Estudos','00000002','202'),
 (5,'Sala de Reunioes','sala',8,'Rua Academica','00000001','104'),
 (6,'Laboratorio Reserva','laboratorio',16,'Rua dos Estudos','00000002','204'),
 (7,'Area de Exposicao','exposicao',120,'Rua da Inovacao','00000003','S/N'),
 (8,'Sala sem Projetor','sala',25,NULL,NULL,NULL);
INSERT INTO recurso(recurso_id,nome,descricao,unidade_medida) VALUES
 (1,'Projetor','Equipamento de projecao','unidade'),
 (2,'Computador','Estacao de trabalho','unidade'),
 (3,'Sistema de audio','Conjunto de som','conjunto'),
 (4,'Internet','Acesso a rede','acesso'),
 (5,'Lousa','Superficie para explicacoes','unidade'),
 (6,'Microfone','Microfone para apresentacoes','unidade'),
 (7,'Kit de robotica','Recurso ainda sem solicitacao','kit'),
 (8,'Mesa de exposicao','Mesa para demonstracoes','unidade');
INSERT INTO espaco_recurso(espaco_id,recurso_id,quantidade_disponivel)
SELECT e.espaco_id,r.recurso_id,
 CASE r.recurso_id
  WHEN 1 THEN CASE WHEN e.espaco_id IN (7,8) THEN 0 ELSE 1 END
  WHEN 2 THEN CASE e.espaco_id WHEN 3 THEN 20 WHEN 4 THEN 12 WHEN 6 THEN 16 ELSE 0 END
  WHEN 3 THEN CASE WHEN e.espaco_id=8 THEN 0 ELSE 1 END
  WHEN 4 THEN 1
  WHEN 5 THEN CASE WHEN e.espaco_id=7 THEN 0 ELSE 1 END
  WHEN 6 THEN CASE WHEN e.espaco_id=1 THEN 4 ELSE 1 END
  WHEN 7 THEN CASE WHEN e.espaco_id IN (3,4,6) THEN 3 ELSE 0 END
  WHEN 8 THEN CASE WHEN e.espaco_id=7 THEN 20 ELSE 4 END
 END
FROM espaco e CROSS JOIN recurso r;

-- 3. Series/edicoes e eventos avulsos. Os encerramentos ocorrem no bloco 8.
INSERT INTO serie(serie_id,nome) VALUES
 (1,'Semana da Computacao'),(2,'Congresso de Dados'),
 (3,'Feira de Inovacao'),(4,'Serie ainda sem edicoes');
INSERT INTO evento(evento_id,serie_id,num_edicao,nome,tipo,data_inicio,data_fim,status) VALUES
 (1,1,10,'Semana da Computacao 2025','semana academica','2025-09-15','2025-09-16','ativo'),
 (2,1,11,'Semana da Computacao 2026','semana academica','2026-11-10','2026-11-12','ativo'),
 (3,1,12,'Semana da Computacao 2027','semana academica','2027-11-10','2027-11-12','planejado'),
 (4,2,1,'Congresso de Dados 2025','congresso','2025-10-20','2025-10-22','ativo'),
 (5,2,2,'Congresso de Dados 2026','congresso','2026-11-10','2026-11-12','ativo'),
 (6,2,3,'Congresso de Dados 2027','congresso','2027-10-18','2027-10-20','planejado'),
 (7,3,1,'Feira de Inovacao 2026','feira','2026-11-20','2026-11-22','ativo'),
 (8,3,2,'Feira de Inovacao 2027','feira','2027-11-19','2027-11-21','planejado'),
 (9,NULL,NULL,'Treinamento Interno 2026','treinamento','2026-11-05','2026-11-06','ativo'),
 (10,NULL,NULL,'Simposio Cancelado 2026','simposio','2026-11-15','2026-11-16','ativo'),
 (11,NULL,NULL,'Encontro Aberto de Pesquisa','encontro','2026-12-03','2026-12-04','ativo');
INSERT INTO promocao_evento(evento_id,agente_id)
SELECT evento_id,1001+((evento_id-1)%4) FROM evento WHERE evento_id NOT IN (9,11)
UNION ALL
SELECT evento_id,2001+((evento_id-1)%4) FROM evento WHERE evento_id NOT IN (9,11);
INSERT INTO promocao_evento VALUES (2,1),(9,2),(11,2004);
INSERT INTO evento_espaco(evento_id,espaco_id)
SELECT evento_id,espaco_id FROM evento CROSS JOIN espaco
WHERE evento_id IN (2,5)
 OR (evento_id BETWEEN 1 AND 10 AND espaco_id IN (1,3,4,5))
 OR (evento_id=11 AND espaco_id=8);

-- 4. Quatro atividades por evento 1..10; duas sessoes por atividade.
-- Exemplo: atividade 22 = evento 2, segunda atividade.
INSERT INTO atividade(atividade_id,evento_id,titulo,tipo_atividade)
SELECT e.evento_id*10+k,e.evento_id,
 CASE k WHEN 1 THEN 'Palestra de Abertura' WHEN 2 THEN 'Workshop de PostgreSQL'
  WHEN 3 THEN 'Minicurso de Python' ELSE
  CASE e.evento_id%3 WHEN 0 THEN 'Mesa-redonda de Tecnologia'
   WHEN 1 THEN 'Painel de Carreiras' ELSE 'Mostra de Projetos' END END,
 CASE k WHEN 1 THEN 'palestra' WHEN 2 THEN 'workshop' WHEN 3 THEN 'minicurso'
  ELSE CASE e.evento_id%3 WHEN 0 THEN 'mesa-redonda' WHEN 1 THEN 'painel' ELSE 'apresentacao' END END
FROM evento e CROSS JOIN generate_series(1,4) AS g(k) WHERE e.evento_id<=10;
INSERT INTO sessao(atividade_id,num_sessao,data_hora_inicio,data_hora_fim,status,inscricao_adicional,limite_vagas)
SELECT a.atividade_id,n,e.data_inicio+(n-1)+
 CASE a.atividade_id%10 WHEN 1 THEN TIME '08:00' WHEN 2 THEN TIME '09:00'
  WHEN 3 THEN TIME '11:00' ELSE TIME '14:00' END,
 e.data_inicio+(n-1)+
 CASE a.atividade_id%10 WHEN 1 THEN TIME '09:00' WHEN 2 THEN TIME '11:00'
  WHEN 3 THEN TIME '13:00' ELSE TIME '15:30' END,
 CASE WHEN e.status='planejado' THEN 'planejada' ELSE 'confirmada' END,
 a.atividade_id%10 IN (2,3),
 CASE WHEN a.atividade_id=22 AND n=1 THEN 5
  WHEN a.atividade_id=23 AND n=2 THEN 4
  WHEN a.atividade_id=52 THEN 8
  WHEN a.atividade_id=53 AND n=2 THEN 10
  WHEN a.atividade_id%10=2 AND n=1 THEN 8
  WHEN a.atividade_id%10=3 AND n=1 AND a.atividade_id<>53 THEN 6
  ELSE NULL END
FROM atividade a JOIN evento e USING(evento_id) CROSS JOIN generate_series(1,2) AS g(n);

-- 5. Necessidades, alocacoes e recursos utilizados.
INSERT INTO sessao_recurso_necessario(atividade_id,num_sessao,recurso_id,quantidade_necessaria)
SELECT s.atividade_id,s.num_sessao,r.recurso_id,
 CASE WHEN r.recurso_id=2 THEN CASE WHEN a.evento_id=5 AND a.atividade_id%10=2 THEN 8
  WHEN a.atividade_id%10=2 THEN 12 ELSE 10 END
  WHEN r.recurso_id=8 THEN 2 ELSE 1 END
FROM sessao s JOIN atividade a USING(atividade_id) CROSS JOIN recurso r
WHERE NOT (s.atividade_id=94 AND s.num_sessao=2)
 AND ((a.atividade_id%10=1 AND r.recurso_id IN (1,3,4))
 OR (a.atividade_id%10 IN (2,3) AND r.recurso_id IN (1,2,4))
 OR (a.atividade_id%10=4 AND r.recurso_id IN (3,4))
 OR (a.tipo_atividade='apresentacao' AND r.recurso_id=8));
INSERT INTO alocacao(alocacao_id,atividade_id,num_sessao,espaco_id,data,status_alocacao)
SELECT s.atividade_id*10+s.num_sessao,s.atividade_id,s.num_sessao,
 CASE WHEN a.evento_id=5 THEN CASE a.atividade_id%10 WHEN 1 THEN 2 WHEN 2 THEN 6 WHEN 3 THEN 3 ELSE 7 END
  ELSE CASE a.atividade_id%10 WHEN 1 THEN 1 WHEN 2 THEN 3 WHEN 3 THEN 4 ELSE 5 END END,
 e.data_inicio-45,CASE WHEN s.status='planejada' THEN 'planejada' ELSE 'confirmada' END
FROM sessao s JOIN atividade a USING(atividade_id) JOIN evento e USING(evento_id)
WHERE s.status='confirmada' OR s.num_sessao=1;
INSERT INTO alocacao_recurso(alocacao_id,recurso_id,quantidade_alocada)
SELECT l.alocacao_id,n.recurso_id,
 CASE WHEN l.atividade_id=32 AND l.num_sessao=1 AND n.recurso_id=2 THEN 8
 ELSE n.quantidade_necessaria END
FROM alocacao l JOIN sessao_recurso_necessario n USING(atividade_id,num_sessao);
INSERT INTO alocacao_recurso(alocacao_id,recurso_id,quantidade_alocada)
SELECT alocacao_id,6,1 FROM alocacao WHERE atividade_id%10=1
UNION ALL SELECT alocacao_id,5,1 FROM alocacao WHERE atividade_id%10=2;
INSERT INTO alocacao_recurso VALUES (942,5,1);
UPDATE alocacao SET status_alocacao='cancelada' WHERE atividade_id=34 AND num_sessao=1;

-- 6. Papeis: atuar/organizar nao exige inscricao como ouvinte.
INSERT INTO papel_evento(pessoa_id,evento_id,funcao)
SELECT 60+evento_id,evento_id,'organizador' FROM evento
UNION ALL SELECT 10+evento_id,evento_id,'coordenador' FROM evento;
INSERT INTO papel_evento VALUES (1,2,'organizador'),(1,2,'coordenador');
INSERT INTO papel_sessao(pessoa_id,atividade_id,num_sessao,papel)
SELECT 60+a.evento_id,s.atividade_id,s.num_sessao,
 CASE s.atividade_id%10 WHEN 1 THEN 'palestrante' WHEN 2 THEN 'instrutor'
 WHEN 3 THEN 'instrutor' ELSE 'mediador' END
FROM sessao s JOIN atividade a USING(atividade_id);
INSERT INTO papel_sessao VALUES (1,21,1,'palestrante'),(1,22,1,'instrutor'),(1,22,2,'instrutor');
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- 7. Inscricoes. ID = evento*1000+pessoa. Ex.: Ana no evento 2 = 2001.
INSERT INTO inscricao_evento(inscricao_id,pessoa_id,evento_id,data_inscricao,status)
SELECT e.evento_id*1000+p.agente_id,p.agente_id,e.evento_id,
 e.data_inicio::timestamp-INTERVAL '30 days'+p.agente_id*INTERVAL '1 minute','confirmada'
FROM evento e CROSS JOIN pessoa p WHERE e.status='ativo'
 AND p.agente_id<=CASE WHEN e.evento_id IN (2,5) THEN 60 ELSE 24 END;
INSERT INTO inscricao_sessao(inscricao_id,atividade_id,num_sessao,data_inscricao,status)
SELECT i.inscricao_id,s.atividade_id,s.num_sessao,
 i.data_inscricao+s.num_sessao*INTERVAL '1 day','confirmada'
FROM inscricao_evento i JOIN atividade a USING(evento_id) JOIN sessao s USING(atividade_id)
WHERE s.status='confirmada' AND s.inscricao_adicional
 AND NOT (s.atividade_id=23 AND s.num_sessao=2)
 AND i.pessoa_id<=CASE
  WHEN s.atividade_id=22 AND s.num_sessao=1 THEN 18
  WHEN s.atividade_id=22 AND s.num_sessao=2 THEN 12
  WHEN s.atividade_id=23 AND s.num_sessao=1 THEN 18
  WHEN s.atividade_id=52 AND s.num_sessao=1 THEN 12
  WHEN s.atividade_id=52 AND s.num_sessao=2 THEN 8
  WHEN s.atividade_id=53 AND s.num_sessao=1 THEN 20
  WHEN s.atividade_id=53 AND s.num_sessao=2 THEN 25
  WHEN a.evento_id IN (1,4) AND s.atividade_id%10=2 AND s.num_sessao=1 THEN 8
  WHEN a.evento_id IN (1,4) AND s.atividade_id%10=3 AND s.num_sessao=1 THEN 6
  WHEN s.atividade_id%10=2 AND s.num_sessao=1 THEN 10
  WHEN s.atividade_id%10=2 AND s.num_sessao=2 THEN 7
  WHEN s.atividade_id%10=3 AND s.num_sessao=1 THEN 9 ELSE 5 END
ORDER BY s.atividade_id,s.num_sessao,i.data_inscricao,i.inscricao_id;
INSERT INTO inscricao_sessao(inscricao_id,atividade_id,num_sessao,data_inscricao,status)
VALUES (2014,22,2,'2026-10-15 09:00','cancelada');
-- As triggers resolvem confirmacoes e espera, respeitando a ordem de inscricao.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

-- 8. Transicoes: cancelar, promover fila, reinscrever e reagendar.
UPDATE inscricao_evento SET status='cancelada' WHERE inscricao_id IN (2002,7024);
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
UPDATE inscricao_sessao SET status='cancelada'
WHERE inscricao_id=2001 AND atividade_id=22 AND num_sessao=1;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
-- Ana retorna ao fim da fila; a trigger renova a data desta inscricao.
UPDATE inscricao_sessao SET status='confirmada'
WHERE inscricao_id=2001 AND atividade_id=22 AND num_sessao=1;
UPDATE sessao SET limite_vagas=12 WHERE atividade_id=53 AND num_sessao=2;
UPDATE sessao SET status='cancelada' WHERE atividade_id=73 AND num_sessao=2;
UPDATE alocacao SET espaco_id=2 WHERE atividade_id=24 AND num_sessao=1;
UPDATE sessao SET data_hora_inicio='2026-11-11 14:00',data_hora_fim='2026-11-11 16:00'
WHERE atividade_id=22 AND num_sessao=2;
UPDATE sessao SET data_hora_inicio='2026-11-05 23:00',data_hora_fim='2026-11-06 01:00'
WHERE atividade_id=94 AND num_sessao=2;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
UPDATE evento SET status='encerrado' WHERE evento_id IN (1,4);
UPDATE evento SET status='cancelado' WHERE evento_id=10;
SET CONSTRAINTS ALL IMMEDIATE;

-- 9. IDs foram explicitos: ajustar sequencias para proximos cadastros.
SELECT setval(pg_get_serial_sequence('serie','serie_id'),(SELECT max(serie_id) FROM serie),true);
SELECT setval(pg_get_serial_sequence('agente','agente_id'),(SELECT max(agente_id) FROM agente),true);
SELECT setval(pg_get_serial_sequence('espaco','espaco_id'),(SELECT max(espaco_id) FROM espaco),true);
SELECT setval(pg_get_serial_sequence('recurso','recurso_id'),(SELECT max(recurso_id) FROM recurso),true);
SELECT setval(pg_get_serial_sequence('evento','evento_id'),(SELECT max(evento_id) FROM evento),true);
SELECT setval(pg_get_serial_sequence('atividade','atividade_id'),(SELECT max(atividade_id) FROM atividade),true);
SELECT setval(pg_get_serial_sequence('alocacao','alocacao_id'),(SELECT max(alocacao_id) FROM alocacao),true);
SELECT setval(pg_get_serial_sequence('inscricao_evento','inscricao_id'),(SELECT max(inscricao_id) FROM inscricao_evento),true);
COMMIT;
