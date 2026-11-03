"""
Prototipo em linha de comando do Sistema de Gestao de Eventos e Espacos.

O programa conecta ao PostgreSQL, executa as cinco consultas definidas no
projeto e tambem aceita perguntas em linguagem natural, que sao convertidas
em SQL por um modelo de linguagem executado localmente pelo Ollama.

Execucao:
    python main.py
"""

import json
import re
from pathlib import Path

import psycopg
from ollama import Client

BASE_DIR = Path(__file__).resolve().parent

with open(BASE_DIR / "config.json", encoding="utf-8") as f:
    config = json.load(f)


def carregar_ddl():
    """Le o DDL a partir de Projeto.txt, no diretorio acima do prototipo."""
    projeto_path = BASE_DIR.parent / "Projeto.txt"
    if not projeto_path.exists():
        print("Erro: Projeto.txt nao encontrado.")
        raise SystemExit(1)
    projeto = projeto_path.read_text(encoding="utf-8")
    ddl = projeto.split("3. DDL COMPLETO", 1)[1]
    ddl = ddl.split("4. CONSULTAS", 1)[0]
    return ddl.strip()


CONSULTAS = [
    {
        "titulo": "Programacao atual do evento 1",
        "sql": """
            SELECT e.evento_id, e.nome AS evento,
                   a.atividade_id, a.titulo AS atividade, s.num_sessao,
                   s.data_hora_inicio, s.data_hora_fim, s.duracao,
                   s.status AS situacao_sessao, ep.nome AS espaco,
                   l.status_alocacao AS situacao_alocacao
            FROM evento e
            JOIN atividade a ON a.evento_id = e.evento_id
            JOIN sessao s ON s.atividade_id = a.atividade_id
            LEFT JOIN alocacao l
                   ON (l.atividade_id, l.num_sessao) = (s.atividade_id, s.num_sessao)
            LEFT JOIN espaco ep ON ep.espaco_id = l.espaco_id
            WHERE e.evento_id = 1
            ORDER BY s.data_hora_inicio, a.atividade_id, s.num_sessao;
        """,
    },
    {
        "titulo": "Pendencias de recursos das sessoes planejadas",
        "sql": """
            WITH recursos_planejados AS (
                SELECT e.evento_id, e.nome AS evento,
                       a.atividade_id, a.titulo AS atividade, s.num_sessao,
                       s.data_hora_inicio, ep.nome AS espaco,
                       COALESCE(l.status_alocacao, 'sem_alocacao') AS situacao_alocacao,
                       r.recurso_id, r.nome AS recurso, n.quantidade_necessaria,
                       CASE WHEN l.status_alocacao IN ('planejada', 'confirmada')
                            THEN COALESCE(u.quantidade_alocada, 0)
                            ELSE 0 END AS quantidade_alocada
                FROM evento e
                JOIN atividade a ON a.evento_id = e.evento_id
                JOIN sessao s ON s.atividade_id = a.atividade_id
                JOIN sessao_recurso_necessario n
                     ON (n.atividade_id, n.num_sessao) = (s.atividade_id, s.num_sessao)
                JOIN recurso r ON r.recurso_id = n.recurso_id
                LEFT JOIN alocacao l
                       ON (l.atividade_id, l.num_sessao) = (s.atividade_id, s.num_sessao)
                LEFT JOIN espaco ep ON ep.espaco_id = l.espaco_id
                LEFT JOIN alocacao_recurso u
                       ON u.alocacao_id = l.alocacao_id AND u.recurso_id = n.recurso_id
                WHERE s.status = 'planejada'
                  AND e.status IN ('planejado', 'ativo')
            )
            SELECT evento_id, evento, atividade_id, atividade, num_sessao,
                   data_hora_inicio, espaco, situacao_alocacao,
                   recurso_id, recurso, quantidade_necessaria, quantidade_alocada,
                   quantidade_necessaria - quantidade_alocada AS quantidade_faltante
            FROM recursos_planejados
            WHERE quantidade_alocada < quantidade_necessaria
            ORDER BY evento_id, atividade_id, num_sessao, recurso_id;
        """,
    },
    {
        "titulo": "Pessoas confirmadas em todas as sessoes restritas do evento 5",
        "sql": """
            WITH parametros AS (
                SELECT 5::bigint AS evento_id
            ),
            sessoes_restritas AS (
                SELECT s.atividade_id, s.num_sessao
                FROM atividade a
                JOIN parametros par ON par.evento_id = a.evento_id
                JOIN sessao s ON s.atividade_id = a.atividade_id
                JOIN alocacao l
                     ON (l.atividade_id, l.num_sessao) = (s.atividade_id, s.num_sessao)
                WHERE s.inscricao_adicional
                  AND s.status = 'confirmada'
                  AND l.status_alocacao = 'confirmada'
            )
            SELECT p.agente_id AS pessoa_id, p.nome
            FROM pessoa p
            JOIN inscricao_evento ie ON ie.pessoa_id = p.agente_id
            JOIN parametros par ON par.evento_id = ie.evento_id
            WHERE ie.status = 'confirmada'
              AND EXISTS (SELECT 1 FROM sessoes_restritas)
              AND NOT EXISTS (
                  SELECT 1
                  FROM sessoes_restritas s
                  WHERE NOT EXISTS (
                      SELECT 1
                      FROM inscricao_sessao i
                      WHERE i.inscricao_id = ie.inscricao_id
                        AND (i.atividade_id, i.num_sessao) = (s.atividade_id, s.num_sessao)
                        AND i.status = 'confirmada'
                  )
              )
            ORDER BY p.agente_id;
        """,
    },
    {
        "titulo": "Tres primeiras pessoas de cada fila de espera elegivel",
        "sql": """
            WITH fila AS (
                SELECT e.evento_id, e.nome AS evento,
                       a.atividade_id, a.titulo AS atividade, s.num_sessao,
                       ie.inscricao_id, p.agente_id AS pessoa_id, p.nome,
                       i.data_inscricao,
                       row_number() OVER (
                           PARTITION BY s.atividade_id, s.num_sessao
                           ORDER BY i.data_inscricao, i.inscricao_id
                       ) AS posicao
                FROM inscricao_sessao i
                JOIN inscricao_evento ie ON ie.inscricao_id = i.inscricao_id
                JOIN pessoa p ON p.agente_id = ie.pessoa_id
                JOIN sessao s
                     ON (s.atividade_id, s.num_sessao) = (i.atividade_id, i.num_sessao)
                JOIN atividade a ON a.atividade_id = s.atividade_id
                JOIN evento e ON e.evento_id = a.evento_id AND e.evento_id = ie.evento_id
                JOIN alocacao l
                     ON (l.atividade_id, l.num_sessao) = (s.atividade_id, s.num_sessao)
                WHERE i.status = 'espera'
                  AND ie.status = 'confirmada'
                  AND e.status = 'ativo'
                  AND s.status = 'confirmada'
                  AND s.inscricao_adicional
                  AND l.status_alocacao = 'confirmada'
            )
            SELECT evento_id, evento, atividade_id, atividade, num_sessao,
                   inscricao_id, pessoa_id, nome, data_inscricao, posicao
            FROM fila
            WHERE posicao <= 3
            ORDER BY evento_id, atividade_id, num_sessao, posicao;
        """,
    },
    {
        "titulo": "Espacos autorizados ao evento 2, com 20 lugares ou mais, livres em 10/11/2026 das 9h as 11h",
        "sql": """
            WITH parametros AS (
                SELECT 2::bigint AS evento_id, 20 AS capacidade_minima,
                       TIMESTAMP '2026-11-10 09:00' AS inicio,
                       TIMESTAMP '2026-11-10 11:00' AS fim
            )
            SELECT ep.espaco_id, ep.nome, ep.capacidade
            FROM parametros par
            JOIN evento e ON e.evento_id = par.evento_id
            JOIN evento_espaco ee ON ee.evento_id = e.evento_id
            JOIN espaco ep ON ep.espaco_id = ee.espaco_id
            WHERE e.status IN ('planejado', 'ativo')
              AND ep.capacidade >= par.capacidade_minima
              AND par.fim > par.inicio
              AND par.inicio >= e.data_inicio::timestamp
              AND par.fim <= (e.data_fim + 1)::timestamp
              AND NOT EXISTS (
                  SELECT 1
                  FROM alocacao l
                  JOIN sessao s
                       ON (s.atividade_id, s.num_sessao) = (l.atividade_id, l.num_sessao)
                  WHERE l.espaco_id = ep.espaco_id
                    AND l.status_alocacao = 'confirmada'
                    AND s.status <> 'cancelada'
                    AND s.data_hora_inicio < par.fim
                    AND s.data_hora_fim > par.inicio
              )
            ORDER BY ep.capacidade DESC, ep.espaco_id;
        """,
    },
]


def conectar():
    db = config["database"]
    return psycopg.connect(
        host=db["host"],
        port=db["port"],
        dbname=db["dbname"],
        user=db["user"],
        password=db["password"],
    )


def imprimir_resultado(colunas, linhas):
    if not colunas:
        print("Comando executado.")
        return
    larguras = [len(c) for c in colunas]
    for linha in linhas:
        for i, valor in enumerate(linha):
            larguras[i] = max(larguras[i], len(str(valor)))
    cabecalho = " | ".join(c.ljust(larguras[i]) for i, c in enumerate(colunas))
    separador = "-+-".join("-" * larguras[i] for i in range(len(colunas)))
    print(cabecalho)
    print(separador)
    for linha in linhas:
        print(" | ".join(str(valor).ljust(larguras[i]) for i, valor in enumerate(linha)))
    print(f"\n{len(linhas)} linha(s).")


def executar_consulta(conn, sql):
    with conn.cursor() as cur:
        cur.execute(sql)
        colunas = [d.name for d in cur.description] if cur.description else []
        linhas = cur.fetchall() if cur.description else []
    return colunas, linhas


def executar_leitura_segura(conn, sql):
    """Executa uma consulta em transacao somente leitura."""
    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute("SET LOCAL transaction_read_only = on")
            # Protocolo preparado recusa multiplos comandos na mesma resposta.
            cur.execute(sql, prepare=True)
            colunas = [d.name for d in cur.description] if cur.description else []
            linhas = cur.fetchall() if cur.description else []
    return colunas, linhas


def limpar_sql(texto):
    """Remove cercas/raciocinio sem truncar ponto e virgula dentro de literais."""
    texto = re.sub(r"<think>.*?</think>", "", texto, flags=re.DOTALL)
    texto = texto.strip()
    if "```" in texto:
        blocos = texto.split("```")
        for i in range(1, len(blocos), 2):
            bloco = blocos[i]
            if bloco[:3].lower() == "sql":
                bloco = bloco[3:]
            texto = bloco.strip()
            break
    return texto.strip().rstrip(";").strip()


def eh_leitura(sql):
    inicio = sql.lstrip().lower()
    return inicio.startswith("select") or inicio.startswith("with")


def gerar_sql(pergunta, ddl, client):
    # Tabelas e views bastam para SELECT; omitir corpos de triggers reduz memoria.
    estruturas = re.findall(r"CREATE (?:TABLE|VIEW)\b.*?;", ddl, flags=re.I | re.S)
    esquema = "\n\n".join(estruturas) if estruturas else ddl
    prompt = (
        "Voce converte perguntas em portugues para uma unica consulta SQL de "
        "leitura no PostgreSQL. Use exclusivamente as tabelas e colunas do "
        "esquema abaixo. Responda apenas com o comando SQL, sem explicacoes e "
        "sem texto adicional.\n\n"
        f"Esquema do banco:\n{esquema}\n\n"
        f"Pergunta: {pergunta}\n"
        "SQL:"
    )
    resposta = client.chat(
        model=config["ollama"]["model"],
        messages=[{"role": "user", "content": prompt}],
        options={"temperature": 0, "num_ctx": 4096, "num_predict": 512},
    )
    return limpar_sql(resposta["message"]["content"])


def menu_consultas(conn):
    print("\nConsultas disponiveis")
    for i, consulta in enumerate(CONSULTAS, start=1):
        print(f"  {i}. {consulta['titulo']}")
    escolha = input("Numero da consulta: ").strip()
    if not escolha.isdigit() or not (1 <= int(escolha) <= len(CONSULTAS)):
        print("Opcao invalida.")
        return
    consulta = CONSULTAS[int(escolha) - 1]
    try:
        colunas, linhas = executar_consulta(conn, consulta["sql"])
        print()
        imprimir_resultado(colunas, linhas)
    except Exception as erro:
        conn.rollback()
        print(f"Erro ao executar a consulta: {erro}")


def menu_pergunta(conn, ddl, client):
    pergunta = input("\nEscreva sua pergunta em portugues: ").strip()
    if not pergunta:
        print("Pergunta vazia.")
        return
    try:
        sql = gerar_sql(pergunta, ddl, client)
    except Exception as erro:
        print(f"Nao foi possivel falar com o Ollama: {erro}")
        return
    if not sql:
        print("O modelo nao retornou nenhuma consulta.")
        return
    print(f"\nSQL gerado:\n{sql}\n")
    if not eh_leitura(sql):
        print("A consulta gerada nao e de leitura e foi bloqueada por seguranca.")
        return
    try:
        colunas, linhas = executar_leitura_segura(conn, sql)
        imprimir_resultado(colunas, linhas)
    except Exception as erro:
        conn.rollback()
        print(f"Erro ao executar a consulta gerada: {erro}")


def main():
    try:
        conn = conectar()
        conn.autocommit = True
    except Exception as erro:
        print(f"Erro ao conectar no PostgreSQL: {erro}")
        raise SystemExit(1)
    print("Conectado ao PostgreSQL.")

    ddl = carregar_ddl()

    client = None
    try:
        client = Client(host=config["ollama"]["host"])
    except Exception as erro:
        print(f"Aviso: nao foi possivel iniciar o cliente Ollama ({erro}).")

    while True:
        print("\n==============================")
        print("1. Executar uma das 5 consultas")
        print("2. Perguntar em linguagem natural")
        print("3. Sair")
        opcao = input("Opcao: ").strip()
        if opcao == "1":
            menu_consultas(conn)
        elif opcao == "2":
            if client is None:
                print("Cliente Ollama indisponivel.")
            else:
                menu_pergunta(conn, ddl, client)
        elif opcao == "3":
            break
        else:
            print("Opcao invalida.")

    conn.close()
    print("Conexao encerrada.")


if __name__ == "__main__":
    main()
