# Roteiro de desenvolvimento — Gestão de Eventos e Espaços

Status: planejamento inicial; implementação ainda não iniciada.

Este roteiro transforma o enunciado em tickets copiáveis para um quadro de trabalho. Os nomes de arquivos, exceto `DML.sql` exigido no enunciado, são propostas provisórias. A organização final do repositório depende do template do professor. Não criar uma interface gráfica: a aplicação será de linha de comando.

## Como usar

- Cada seção `BD-XX` corresponde a um ticket; seu título pode ser usado diretamente em uma issue.
- As dependências indicam o que precisa estar concluído antes do aceite do ticket. A preparação pode começar antes.
- As caixas são critérios de aceite, não tarefas já realizadas.
- As propostas de domínio abaixo precisam ser validadas antes de virarem regras no modelo e no código.
- Concluir primeiro BD-01 a BD-05 para estabilizar o domínio. Não começar pelo SQL gerado por IA.

## Visão das etapas

| Etapa | Tickets | Resultado esperado |
| --- | --- | --- |
| Entendimento e modelagem | BD-01 a BD-05 | Requisitos, decisões, modelo conceitual e modelo relacional coerentes |
| Ambiente e banco | BD-06 a BD-11 | PostgreSQL com estrutura, restrições e quatro finalidades distintas de triggers |
| Dados e consultas | BD-12 a BD-14 | DML.sql, cinco consultas e banco testado |
| Aplicação e Ollama | BD-15 a BD-20 | CLI integrada ao banco e ao modelo local, com execução controlada |
| Documentação e entrega | BD-21 a BD-24 | Evidências, template atendido e execução reproduzível |

## Etapa 1 — Entendimento e modelagem

### BD-01 — Consolidar requisitos e limites do projeto

**Objetivo:** transformar o enunciado em uma lista verificável de requisitos.

**Dependências:** nenhuma.

**Entregável:** matriz de requisitos com identificador, origem, regra, ticket responsável e evidência esperada.

**Critérios de aceite:**

- [ ] Cobrir eventos, promotores, pessoas, papéis, atividades, sessões, espaços, recursos e inscrições.
- [ ] Registrar PostgreSQL obrigatório, Python >= 3.11, Ollama local e interface de linha de comando.
- [ ] Registrar modelo conceitual, mapeamento relacional, DDL, DML.sql, cinco consultas, funções e pelo menos quatro triggers com finalidades distintas.
- [ ] Mapear os oito comportamentos exigidos para o protótipo aos tickets BD-15 a BD-20.
- [ ] Distinguir requisitos do professor, escolhas do grupo e funcionalidades opcionais. Pagamentos, certificados e interface web ficam fora do escopo inicial, salvo nova exigência.
- [ ] Registrar que o template de entrega ainda será recebido; não inventar exigências de organização.

### BD-02 — Decidir as seis questões de modelagem do enunciado

**Objetivo:** registrar escolhas e justificativas antes de desenhar tabelas.

**Dependências:** BD-01.

**Entregável:** registro de decisões com uma resposta explícita para cada questão.

**Propostas iniciais para discussão, ainda não aprovadas:**

| Questão | Proposta de partida | Ponto a resolver no ticket |
| --- | --- | --- |
| 1. Promotores | Um promotor representa uma pessoa ou organização; um evento admite vários promotores por uma associação | Representar a distinção pessoa/organização e garantir que cada promotor tenha exatamente uma dessas naturezas; definir se eventos em rascunho podem ficar sem promotor |
| 2. Papéis | Identidade única de pessoa, inscrição no evento e associações de papéis; papéis podem coexistir | Separar organizadores no evento de palestrantes/instrutores nas sessões e decidir se estes precisam de inscrição como participantes |
| 3. Atividade e sessão | Atividade guarda título, descrição e tipo; sessão guarda início, fim, espaço e regras de inscrição | Atividade pertence a uma edição e pode ter várias sessões; definir onde ficam responsáveis e requisitos de recursos |
| 4. Edições | Iniciativa recorrente agrupa edições, cada uma tratada como evento com datas e programação próprias | Definir os dados compartilhados e permitir eventos únicos sem uma série recorrente |
| 5. Vagas | Sessão restrita exige inscrição adicional; limite próprio não pode exceder capacidade física; lotação gera espera | Definir limite efetivo, fila, cancelamento, reinscrição e comportamento das sessões de programação geral |
| 6. Histórico | Preservar programação atual e registrar alterações de horário/espaço em histórico | Definir dados anteriores/novos, instante, motivo e autoria; a identidade do usuário da aplicação não deve ser confundida com a conta técnica do banco |

**Critérios de aceite:**

- [ ] Cada uma das seis decisões possui alternativa escolhida, justificativa e exemplo de uso.
- [ ] Regras para dados opcionais, cardinalidades mínimas e exclusão de registros estão explícitas.
- [ ] Uma mesma pessoa pode exercer os papéis escolhidos sem duplicar seu cadastro.
- [ ] O exemplo de um workshop com duas sessões pode ser representado sem duplicar a atividade.
- [ ] As decisões são refletidas nos tickets seguintes; qualquer mudança posterior exige atualizar modelos e implementação.

### BD-03 — Especificar regras operacionais e casos de conflito

**Objetivo:** definir o que o sistema aceita, rejeita e registra em situações concretas.

**Dependências:** BD-02.

**Entregável:** catálogo de regras e cenários de teste.

**Critérios de aceite:**

- [ ] Definir estados permitidos para evento, sessão e inscrição e suas transições, incluindo cancelamento.
- [ ] Definir datas, horários e fuso; sessão deve ter duração positiva e caber no período do evento.
- [ ] Definir conflito de espaço entre quaisquer eventos e permitir horários consecutivos sem falsa sobreposição.
- [ ] Definir se conflitos de palestrantes/instrutores também serão impedidos ou apenas consultados, justificando a escolha.
- [ ] Definir recursos exigidos e disponíveis, incluindo se haverá quantidades; evitar inventário de equipamentos móveis caso não seja necessário.
- [ ] Especificar capacidade física, limite da sessão e tratamento de sessões sem inscrição específica. Sem controle de entrada, não prometer medição de ocupação real nessas sessões.
- [ ] Especificar pré-requisito de inscrição ativa no evento para inscrição na sessão, duplicidade, espera, ordem da fila, promoção após cancelamento e reinscrição.
- [ ] Definir o efeito do cancelamento de um evento ou sessão sobre inscrições, filas e reserva de espaço.
- [ ] Definir o efeito de mudanças posteriores: redução de capacidade, retirada de recurso, mudança do período do evento e troca de sala/horário com inscrições existentes.
- [ ] Identificar quais regras serão garantidas por constraints, triggers, funções ou aplicação, evitando depender apenas da CLI para integridade.

### BD-04 — Produzir o modelo conceitual

**Objetivo:** representar o domínio sem antecipar detalhes de implementação SQL.

**Dependências:** BD-02 e BD-03.

**Entregável:** diagrama conceitual e explicação das entidades e relacionamentos.

**Critérios de aceite:**

- [ ] Identificar entidades, atributos, identificadores, relacionamentos e cardinalidades mínimas/máximas.
- [ ] Representar promotores, edições, papéis simultâneos, atividade/sessão, inscrições, recursos e histórico conforme as decisões.
- [ ] Explicitar especializações e participação obrigatória quando utilizadas.
- [ ] Validar o diagrama com exemplos de promoção conjunta, múltiplas sessões e inscrição adicional.
- [ ] Preservar fonte editável e versão legível para revisão; adequar formato ao template quando ele chegar.

### BD-05 — Mapear para o modelo relacional e criar dicionário de dados

**Objetivo:** transformar o modelo conceitual em relações implementáveis.

**Dependências:** BD-04.

**Entregável:** esquema relacional, mapeamento justificado e dicionário de dados.

**Critérios de aceite:**

- [ ] Listar tabelas, atributos, domínios, PKs, FKs, chaves candidatas, nulabilidade e unicidades.
- [ ] Explicar o mapeamento de relacionamentos N:N, especializações e histórico.
- [ ] Revisar dependências funcionais e normalização até 3FN, justificando eventuais exceções.
- [ ] Definir política de ON DELETE e ON UPDATE para cada FK, inclusive quando não haverá cascata.
- [ ] Identificar valores calculados e avaliar atributo gerado pertinente, por exemplo duração derivada exclusivamente do início/fim da sessão; não usá-lo para contagens de outras tabelas.
- [ ] Verificar correspondência entre os modelos e o catálogo de regras.

## Etapa 2 — Ambiente e implementação do banco

### BD-06 — Preparar ambiente e fluxo local de desenvolvimento

**Objetivo:** permitir que o grupo use o mesmo ambiente e controle versões com segurança.

**Dependências:** BD-01; pode ocorrer junto à modelagem.

**Entregável:** instruções de ambiente e arquivos mínimos de configuração, em estrutura provisória.

**Critérios de aceite:**

- [ ] Verificar e registrar versões efetivamente utilizadas de Python >= 3.11, PostgreSQL e Ollama.
- [ ] Escolher editor/IDE e configurar ambiente virtual e dependências Python reproduzíveis.
- [ ] Definir como executar PostgreSQL localmente; Docker é uma possibilidade, não uma exigência do professor.
- [ ] Configurar exemplos de conexão e exclusão de senhas, ambiente virtual e arquivos locais pelo .gitignore.
- [ ] Distinguir conta de criação/carga do banco da conta restrita usada para consultas do protótipo.
- [ ] Definir convenção simples para commits e fluxo de branches; o remoto origin já foi configurado, mas deve ser verificado ao executar o ticket.

### BD-07 — Implementar DDL e funções de apoio

**Objetivo:** criar o esquema PostgreSQL a partir do modelo aprovado.

**Dependências:** BD-05 e BD-06.

**Entregável:** script DDL, funções necessárias e instruções de criação.

**Critérios de aceite:**

- [ ] Implementar PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT e tipos adequados conforme o dicionário.
- [ ] Implementar e justificar ações ON DELETE/ON UPDATE e atributos gerados pertinentes.
- [ ] Criar funções com responsabilidades claras, sem duplicar regras de forma inconsistente.
- [ ] Impedir conflito de reservas de espaço no próprio banco, inclusive sob concorrência; avaliar constraint de exclusão e documentar qualquer extensão necessária.
- [ ] Criar índices justificados por integridade e consultas, sem indexar todos os campos automaticamente.
- [ ] Executar o script em um banco de testes vazio e conferir tabelas, funções e restrições criadas.

### BD-08 — Implementar trigger de coerência temporal da sessão

**Objetivo:** impedir programação incompatível com o período do evento.

**Dependências:** BD-03 e BD-07.

**Entregável:** trigger/função de validação temporal e casos de teste.

**Critérios de aceite:**

- [ ] Validar inserção e alteração de sessões contra início/fim do evento.
- [ ] Tratar também alterações no período do evento que invalidariam sessões existentes.
- [ ] Produzir erro compreensível e manter a transação consistente.
- [ ] Testar limites exatos, duração inválida e alteração válida; documentar o que já é garantido por CHECK.

### BD-09 — Implementar trigger de compatibilidade de recursos

**Objetivo:** impedir alocação de sessão em espaço que não atende aos recursos exigidos.

**Dependências:** BD-03 e BD-07.

**Entregável:** trigger/função de validação de recursos e testes.

**Critérios de aceite:**

- [ ] Validar alocação/troca de espaço e mudança de requisitos segundo a decisão sobre recursos.
- [ ] Cobrir retirada ou alteração de recurso disponível que afete sessões já programadas.
- [ ] Definir tratamento dos estados cancelados e concorrência em alterações relacionadas.
- [ ] Testar espaço compatível, recurso ausente e mudança que tornaria uma alocação inválida.

### BD-10 — Implementar trigger de admissão e controle de vagas

**Objetivo:** aplicar regras de inscrição adicional sem exceder vagas.

**Dependências:** BD-03 e BD-07.

**Entregável:** trigger/funções de inscrição, fila e cancelamento conforme as regras aprovadas.

**Critérios de aceite:**

- [ ] Validar inscrição ativa no evento, sessão elegível, duplicidade e capacidade efetiva.
- [ ] Aceitar ou direcionar para espera conforme a regra; não usar apenas contagem desprotegida contra acessos simultâneos.
- [ ] Tratar cancelamento, promoção ordenada da fila e reinscrição de forma transacional.
- [ ] Tratar cancelamento do evento/sessão e alteração de limite/capacidade sem inscrições órfãs ou excesso de confirmados.
- [ ] Testar duas conexões disputando a última vaga e verificar que no máximo uma obtém confirmação.
- [ ] Se a solução exigir várias triggers, documentar que elas pertencem à mesma finalidade de controle de vagas.

### BD-11 — Implementar trigger de histórico da programação

**Objetivo:** preservar alterações de horário e espaço de uma sessão.

**Dependências:** BD-03 e BD-07.

**Entregável:** histórico e trigger/função de auditoria.

**Critérios de aceite:**

- [ ] Registrar dados anteriores/novos, instante e autoria/motivo conforme a decisão BD-02.
- [ ] Registrar mudanças reais de horário/espaço; atualização sem mudança não gera ruído.
- [ ] Garantir que alteração rejeitada ou revertida não deixe histórico confirmado.
- [ ] Definir preservação do histórico em exclusões e impedir sua adulteração pela conta restrita da aplicação.
- [ ] Demonstrar as quatro finalidades distintas: temporal, recursos, vagas e histórico. Não contar uma função auxiliar como uma trigger adicional.

## Etapa 3 — Dados, consultas e validação do banco

### BD-12 — Produzir DML.sql com cenários demonstráveis

**Objetivo:** popular o banco com dados fictícios suficientes para demonstrar as regras.

**Dependências:** BD-08 a BD-11.

**Entregável:** arquivo obrigatório `DML.sql` e resumo dos cenários carregados.

**Critérios de aceite:**

- [ ] Incluir promotores pessoa/organização, promoção conjunta, edições e pessoas com papéis simultâneos.
- [ ] Incluir atividades com várias sessões, espaços de capacidades diferentes e recursos distintos.
- [ ] Incluir programação geral, sessões restritas, inscrições confirmadas, fila e cancelamentos conforme escopo aprovado.
- [ ] Incluir mudanças válidas de programação que produzam histórico.
- [ ] Garantir que as cinco consultas tenham resultados interpretáveis e casos de borda úteis, como sessão sem inscritos e espaço sem sessão.
- [ ] Separar comandos propositalmente inválidos dos dados de carga: DML.sql deve completar sem erros.
- [ ] Documentar como recriar a base de demonstração sem apagar dados fora de um ambiente de testes explicitamente identificado.

### BD-13 — Definir e implementar as cinco consultas SQL

**Objetivo:** responder cinco perguntas úteis, com complexidades diferentes.

**Dependências:** BD-05 e BD-12.

**Entregável:** cinco consultas numeradas, enunciados, parâmetros e exemplos de resultados.

**Conjunto proposto, a validar com o conteúdo da disciplina:**

| Consulta | Pergunta de negócio | Conteúdos previstos |
| --- | --- | --- |
| Q1 | Qual é a programação de um evento em determinada data, com atividade, horário e espaço? | JOIN, filtros e ordenação |
| Q2 | Quais pessoas estão inscritas em um evento e quais papéis exercem nele e em suas sessões? | Múltiplos JOINs, LEFT JOIN e tratamento de multiplicidade |
| Q3 | Quantas inscrições confirmadas, pessoas em espera e vagas disponíveis existem por sessão restrita? | Agregações, GROUP BY, CASE e inclusão de sessões sem inscrições |
| Q4 | Quais espaços acumulam mais horas de programação no período informado? | CTE, agregação e função de janela para ranking |
| Q5 | Quais espaços atendem aos recursos e à capacidade de uma sessão e estão livres no intervalo desejado? | NOT EXISTS, subconsultas correlacionadas e comparação de intervalos |

**Critérios de aceite:**

- [ ] Confirmar que as cinco perguntas têm utilidade e níveis de complexidade distintos.
- [ ] Definir parâmetros e resultados esperados a partir do DML.sql, sem depender de IDs arbitrários não documentados.
- [ ] Evitar contagem duplicada ao combinar papéis, recursos e inscrições.
- [ ] Tratar cancelamentos, sessões sem inscrição específica, filas e intervalos conforme o domínio.
- [ ] Definir em Q4 a regra para sessões parcialmente sobrepostas ao período e distinguir horas programadas de ocupação real.
- [ ] Usar as mesmas cinco consultas no protótipo, sem versões divergentes.

### BD-14 — Validar integridade, triggers e concorrência no PostgreSQL

**Objetivo:** demonstrar as regras no SGBD exigido, inclusive quando a CLI é contornada.

**Dependências:** BD-08 a BD-13.

**Entregável:** testes SQL/Python de integração e evidências de execução.

**Critérios de aceite:**

- [ ] Testar PK/FK/UNIQUE/CHECK, nulabilidade, valores padrão, atributo gerado e ações referenciais relevantes.
- [ ] Testar sucesso, rejeição e rollback de cada uma das quatro finalidades de trigger.
- [ ] Testar conflitos de espaço em inserções, reagendamentos e operações concorrentes, inclusive entre eventos diferentes.
- [ ] Testar capacidade, espera e duas transações disputando a última vaga, sem ultrapassar o limite.
- [ ] Testar alterações dos registros relacionados: evento, espaço e recursos, cobrindo os caminhos definidos em BD-03.
- [ ] Conferir resultados das cinco consultas com expectativas explícitas.
- [ ] Executar em PostgreSQL real, em banco de testes, e registrar versões/comandos usados.

## Etapa 4 — Protótipo Python e Ollama

### BD-15 — Implementar CLI e conexão parametrizável ao PostgreSQL

**Objetivo:** permitir que o usuário informe os dados de conexão e conecte ao banco do projeto.

**Dependências:** BD-06 e BD-07.

**Entregável:** aplicação de linha de comando com configuração de conexão.

**Critérios de aceite:**

- [ ] Receber host, porta, banco, usuário e senha, com entrada da senha sem exibição; configuração local opcional não deve expor segredos.
- [ ] Mostrar sucesso ou erro de conexão de modo compreensível, sem imprimir credenciais.
- [ ] Fechar conexões e recuperar-se de falhas sem deixar transações abertas.
- [ ] Disponibilizar menu para as cinco consultas, pergunta livre e saída.
- [ ] Executar com Python >= 3.11 e dependências documentadas.

### BD-16 — Executar as cinco consultas pelo menu

**Objetivo:** disponibilizar Q1 a Q5 com parâmetros e resultados legíveis.

**Dependências:** BD-13 e BD-15.

**Entregável:** opções de consulta implementadas na CLI.

**Critérios de aceite:**

- [ ] Coletar e validar parâmetros necessários a cada consulta.
- [ ] Enviar valores por parâmetros do driver, sem concatenação de entrada do usuário no SQL.
- [ ] Apresentar colunas, datas, horários, valores nulos e ausência de resultados adequadamente.
- [ ] Tratar erros e retornar ao menu sem encerrar a aplicação inesperadamente.
- [ ] Conferir que cada opção produz o mesmo resultado da consulta SQL correspondente.

### BD-17 — Preparar Ollama e escolher um modelo local viável

**Objetivo:** executar um modelo de linguagem localmente no computador de demonstração.

**Dependências:** BD-06.

**Entregável:** configuração local documentada e teste de comunicação Python–Ollama.

**Critérios de aceite:**

- [ ] Verificar memória e capacidade do equipamento antes de escolher modelo e tamanho; não fixar modelo sem teste local.
- [ ] Instalar/verificar Ollama, obter o modelo escolhido e registrar nome, versão/identificador e comandos necessários.
- [ ] Receber uma resposta pela integração Python e registrar tempo de resposta observado.
- [ ] Garantir inferência local; após baixar as dependências/modelo, não depender de uma API de inferência em nuvem.
- [ ] Tratar serviço indisponível, modelo ausente e tempo limite com mensagens claras.

### BD-18 — Converter perguntas em português para SQL com contexto do esquema

**Objetivo:** gerar consultas compatíveis com o banco real por meio do Ollama.

**Dependências:** BD-05 e BD-17.

**Entregável:** integração de geração SQL, contexto do esquema e conjunto de perguntas de avaliação.

**Critérios de aceite:**

- [ ] Enviar ao modelo esquema autorizado, relações, regras relevantes e instrução para produzir SQL PostgreSQL de consulta.
- [ ] Manter o contexto sincronizado com o DDL final; não enviar senhas nem dados pessoais desnecessários.
- [ ] Receber pergunta em linguagem natural e obter SQL, tratando saída vazia, cercas de código e formato inesperado.
- [ ] Exibir o SQL gerado na CLI para tornar a demonstração verificável.
- [ ] Preparar perguntas baseadas em Q1–Q5, paráfrases, ambiguidades, objetos inexistentes e pedidos fora do domínio.
- [ ] Registrar acertos, erros e limitações observadas; não prometer que o modelo sempre produz SQL correto.

### BD-19 — Executar SQL gerado com permissões restritas e limites

**Objetivo:** executar perguntas geradas sem permitir alteração do banco ou acesso arbitrário.

**Dependências:** BD-15 e BD-18.

**Entregável:** camada de validação/execução e configuração das permissões.

**Critérios de aceite:**

- [ ] Usar conta sem superusuário e com leitura apenas nos objetos autorizados, sem poderes de escrita, criação ou execução de funções privilegiadas do projeto.
- [ ] Executar em transação somente leitura, com tempo limite e limite de resultados exibidos.
- [ ] Validar uma única instrução de consulta e os objetos permitidos; considerar CTEs e comandos disfarçados. Expressões regulares isoladas não são a barreira de segurança.
- [ ] Revisar permissões de funções/esquemas e contexto de resolução de nomes; rejeitar chamadas e objetos fora da política definida.
- [ ] Testar tentativas de escrita, múltiplos comandos, CTE com escrita, função com efeito colateral, leitura de objetos não autorizados e consulta excessivamente demorada.
- [ ] Apresentar resultado ou erro SQL compreensível e permitir nova pergunta após rollback.
- [ ] Não executar automaticamente reparos de DDL ou DML propostos pelo modelo.

### BD-20 — Validar o protótipo de ponta a ponta

**Objetivo:** provar a integração aplicação–PostgreSQL–Ollama solicitada pelo professor.

**Dependências:** BD-14, BD-16 e BD-19.

**Entregável:** roteiro de demonstração executado e registro dos resultados.

**Critérios de aceite:**

- [ ] Informar parâmetros, conectar ao banco e executar as cinco consultas pelo menu.
- [ ] Enviar pergunta em português, gerar SQL pelo Ollama local, executar e apresentar resultado correto em caso demonstrável.
- [ ] Mostrar erro de SQL gerado incorretamente e recuperação para a próxima interação.
- [ ] Demonstrar pergunta sem resultados, falha de conexão, Ollama indisponível e bloqueio de pedido de alteração dos dados.
- [ ] Verificar que a geração local funciona sem serviço de inferência externo após a preparação do ambiente.
- [ ] Relacionar explicitamente as evidências aos oito itens do protótipo no enunciado.

## Etapa 5 — Documentação e entrega

### BD-21 — Consolidar documentação técnica e evidências

**Objetivo:** explicar o sistema e justificar decisões com base no que foi implementado.

**Dependências:** BD-20; documentação deve ser atualizada durante as etapas anteriores.

**Entregável:** documentação revisada e evidências de execução.

**Critérios de aceite:**

- [ ] Incluir escopo, seis decisões, catálogo de regras, modelo conceitual, mapeamento relacional e dicionário de dados.
- [ ] Explicar constraints, funções e quatro finalidades de triggers, indicando cenários de demonstração.
- [ ] Apresentar as cinco perguntas SQL, sua utilidade, parâmetros e resultados de exemplo.
- [ ] Documentar instalação, conexão, execução da CLI, modelo Ollama, permissões e limitações observadas.
- [ ] Manter consistência entre diagramas, scripts, aplicação e texto; não documentar funcionalidade planejada como pronta.

### BD-22 — Adequar o repositório ao template do professor

**Objetivo:** atender ao formato oficial sem antecipar sua estrutura.

**Dependências:** recebimento do template e BD-21 para aceite final.

**Entregável:** matriz template–artefatos e repositório organizado conforme a exigência recebida.

**Critérios de aceite:**

- [ ] Ler o template real e identificar nomes, diretórios, arquivos .txt, diagramas, relatórios e demais itens exigidos.
- [ ] Comparar template e enunciado com os artefatos existentes, criando tickets adicionais se surgir requisito novo.
- [ ] Apresentar plano exato antes de reorganizações amplas; preservar caminhos até a revisão do plano.
- [ ] Ajustar comandos, referências e documentação após as mudanças aprovadas.
- [ ] Conferir todos os arquivos exigidos, incluindo DML.sql, sem presumir formato antes de receber o template.

### BD-23 — Ensaiar instalação e demonstração a partir de uma cópia limpa

**Objetivo:** verificar que outra pessoa consegue reproduzir a entrega.

**Dependências:** BD-22.

**Entregável:** checklist de reprodução executado e correções necessárias.

**Critérios de aceite:**

- [ ] Partir de cópia limpa do repositório, ambiente Python novo e banco de testes vazio.
- [ ] Seguir apenas as instruções entregues para criar o esquema, funções/triggers, carregar DML.sql e iniciar a aplicação.
- [ ] Preparar modelo Ollama e permissões sem depender de configurações pessoais ocultas.
- [ ] Executar testes do banco, cinco consultas e demonstração de linguagem natural no PostgreSQL real.
- [ ] Corrigir dependências ausentes, caminhos locais e divergências; registrar evidências da execução final.

### BD-24 — Revisar rastreabilidade e preparar a versão de entrega no Git

**Objetivo:** fechar a entrega contra os requisitos, e não apenas contra o que foi desenvolvido.

**Dependências:** BD-23.

**Entregável:** matriz de requisitos encerrada e versão revisável no repositório.

**Critérios de aceite:**

- [ ] Para cada requisito do enunciado e do template, indicar arquivo e evidência que provam atendimento.
- [ ] Verificar todos os critérios, ausência de segredos e exclusão de arquivos temporários/ambiente virtual.
- [ ] Revisar diff, organizar commits compreensíveis e preparar instruções de entrega.
- [ ] Publicar commits/tag no remoto conforme o fluxo acordado com o grupo; este roteiro, por si só, não executa publicação.
- [ ] Confirmar que não há pendência obrigatória antes de marcar o projeto como concluído.

## Pontos de revisão

1. **Após BD-05:** revisar as seis decisões e os dois modelos antes de implementar o banco.
2. **Após BD-14:** verificar DDL, DML.sql, cinco consultas e quatro finalidades de triggers funcionando no PostgreSQL.
3. **Após BD-20:** verificar os oito comportamentos do protótipo com Ollama local.
4. **Após BD-23:** conferir reprodução, template e evidências antes da entrega.

## Cobertura do enunciado

| Exigência | Tickets responsáveis | Evidência final esperada |
| --- | --- | --- |
| Entendimento do domínio e seis decisões | BD-01 a BD-03 | Matriz de requisitos e decisões justificadas |
| Modelo conceitual | BD-04 | Diagrama e descrição |
| Mapeamento relacional | BD-05 | Esquema relacional, mapeamento e dicionário |
| PostgreSQL, DDL e recursos estudados | BD-06 a BD-11, BD-14 | Scripts executados e testes de integridade |
| Pelo menos quatro triggers distintas | BD-08 a BD-11, BD-14 | Definições e testes das quatro finalidades |
| Dados suficientes e DML.sql | BD-12 | Carga executável e cenários demonstráveis |
| Cinco consultas relevantes | BD-13, BD-14, BD-16 | SQL, resultados esperados e execução pela CLI |
| Python >= 3.11 e ambiente adequado | BD-06, BD-15 | Versões, dependências e comandos verificados |
| Protótipo 1–2: parâmetros e conexão | BD-15, BD-20 | Execução na CLI |
| Protótipo 3–4: cinco consultas e apresentação | BD-16, BD-20 | Execução de Q1–Q5 |
| Protótipo 5–6: pergunta natural e conversão local | BD-17, BD-18, BD-20 | Pergunta e SQL gerado pelo Ollama |
| Protótipo 7–8: executar e mostrar resultado/erro | BD-19, BD-20 | Resultados, falhas e recuperação |
| Formato de repositório ainda a receber | BD-22 | Checklist do template real |
| Entrega documentada e reproduzível | BD-21 a BD-24 | Documentação, ensaio limpo e revisão final |

## Próxima ação

Começar por BD-01 e discutir BD-02 com o grupo. As propostas não fecham decisões antecipadamente. O template pode ser incorporado assim que chegar, mesmo antes do início da implementação. Não foram criadas issues remotas, executado código do sistema ou publicados commits nesta etapa de planejamento.
