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
        "titulo": "Programacao completa do evento 2",
        "sql": """
            SELECT e.nome AS evento, a.titulo AS atividade,
                   s.data, s.hora_inicio, s.hora_fim, ep.nome AS espaco
            FROM evento e
            JOIN atividade a ON a.evento_id = e.id
            JOIN sessao s ON s.atividade_id = a.id
            JOIN espaco ep ON ep.id = s.espaco_id
            WHERE e.id = 2
            ORDER BY s.data, s.hora_inicio
        """,
    },
    {
        "titulo": "Ocupacao das sessoes que exigem inscricao",
        "sql": """
            SELECT s.id AS sessao_id, a.titulo AS atividade, s.data,
                   COALESCE(s.limite_vagas, ep.capacidade) AS limite_efetivo,
                   count(i.pessoa_id) FILTER (WHERE i.status = 'confirmada') AS confirmadas,
                   COALESCE(s.limite_vagas, ep.capacidade)
                       - count(i.pessoa_id) FILTER (WHERE i.status = 'confirmada') AS vagas_restantes
            FROM sessao s
            JOIN atividade a ON a.id = s.atividade_id
            JOIN espaco ep ON ep.id = s.espaco_id
            LEFT JOIN inscricao_sessao i ON i.sessao_id = s.id
            WHERE s.requer_inscricao = true
            GROUP BY s.id, a.titulo, s.data, s.limite_vagas, ep.capacidade
            ORDER BY s.id
        """,
    },
    {
        "titulo": "Pessoas confirmadas em todas as sessoes restritas do evento 2",
        "sql": """
            SELECT p.id, p.nome
            FROM pessoa p
            JOIN inscricao_evento ie
                 ON ie.pessoa_id = p.id AND ie.evento_id = 2 AND ie.status = 'confirmada'
            WHERE NOT EXISTS (
                SELECT 1
                FROM sessao s
                JOIN atividade a ON a.id = s.atividade_id
                WHERE a.evento_id = 2 AND s.requer_inscricao = true
                  AND NOT EXISTS (
                      SELECT 1 FROM inscricao_sessao i
                      WHERE i.sessao_id = s.id
                        AND i.pessoa_id = p.id
                        AND i.status = 'confirmada'
                  )
            )
            ORDER BY p.id
        """,
    },
    {
        "titulo": "Tres sessoes com maior ocupacao em cada evento",
        "sql": """
            WITH ocupacao AS (
                SELECT e.id AS evento_id, s.id AS sessao_id, a.titulo AS atividade,
                       ep.capacidade,
                       count(i.pessoa_id) FILTER (WHERE i.status = 'confirmada') AS confirmadas
                FROM evento e
                JOIN atividade a ON a.evento_id = e.id
                JOIN sessao s ON s.atividade_id = a.id
                JOIN espaco ep ON ep.id = s.espaco_id
                LEFT JOIN inscricao_sessao i ON i.sessao_id = s.id
                GROUP BY e.id, s.id, a.titulo, ep.capacidade
            ),
            ranking AS (
                SELECT o.*,
                       round(o.confirmadas::numeric / o.capacidade, 3) AS taxa_ocupacao,
                       row_number() OVER (
                           PARTITION BY o.evento_id
                           ORDER BY o.confirmadas::numeric / o.capacidade DESC, o.sessao_id
                       ) AS posicao
                FROM ocupacao o
            )
            SELECT evento_id, sessao_id, atividade, confirmadas, capacidade, taxa_ocupacao, posicao
            FROM ranking
            WHERE posicao <= 3
            ORDER BY evento_id, posicao
        """,
    },
    {
        "titulo": "Espacos para 50 ou mais pessoas livres em 15/09/2026 entre 9h e 11h",
        "sql": """
            SELECT ep.id, ep.nome, ep.capacidade
            FROM espaco ep
            WHERE ep.capacidade >= 50
              AND NOT EXISTS (
                  SELECT 1 FROM sessao s
                  WHERE s.espaco_id = ep.id
                    AND s.data = DATE '2026-09-15'
                    AND s.hora_inicio < TIME '11:00'
                    AND s.hora_fim > TIME '09:00'
              )
            ORDER BY ep.capacidade DESC
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
            cur.execute(sql)
            colunas = [d.name for d in cur.description] if cur.description else []
            linhas = cur.fetchall() if cur.description else []
    return colunas, linhas


def limpar_sql(texto):
    """Remove raciocinio do modelo e cercas de codigo, devolvendo um unico comando."""
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
    if ";" in texto:
        texto = texto.split(";", 1)[0]
    return texto.strip()


def eh_leitura(sql):
    inicio = sql.lstrip().lower()
    return inicio.startswith("select") or inicio.startswith("with")


def gerar_sql(pergunta, ddl, client):
    prompt = (
        "Voce converte perguntas em portugues para uma unica consulta SQL de "
        "leitura no PostgreSQL. Use exclusivamente as tabelas e colunas do "
        "esquema abaixo. Responda apenas com o comando SQL, sem explicacoes e "
        "sem texto adicional.\n\n"
        f"Esquema do banco:\n{ddl}\n\n"
        f"Pergunta: {pergunta}\n"
        "SQL:"
    )
    resposta = client.chat(
        model=config["ollama"]["model"],
        messages=[{"role": "user", "content": prompt}],
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
