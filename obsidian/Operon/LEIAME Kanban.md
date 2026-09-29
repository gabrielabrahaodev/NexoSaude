# Kanban NexoSaúde (Operon) — guia de 5 minutos

## Board pronto: "Kanban NexoSaúde" (já criado neste vault)

Preset criado em `.obsidian/plugins/operon/data.json`: pipeline Project, filtro por prefixo de ID (`operonId` contém `nx-`), swimlanes por prioridade. É só abrir no Operon Kanban. Backup do config anterior em `data.json.bak` (mesma pasta). **Convenção permanente: todo ID nosso começa com `nx-`** — é o que o filtro usa (tags continuam para busca/grafo).

## Opção 1 — board simples (plugin Kanban)

Abra [[Kanban NexoSaúde]] com o plugin Kanban instalado: 4 colunas (A Fazer, Depois, Estacionado, Concluído), cards linkados aos épicos e ao backlog. Mover card = editar a linha (arrastar entre colunas move o `- [ ]`).

## Pipeline em uso (não inventar nomes!)

`Brainstorming` → `Planned` → `InProgress` → `Finished` (concluído) / `Paused` (estacionado) / `Dropped`. Nossas tasks usam exatamente estes: backlog em `Planned`, épicos em `Finished`, estacionados em `Paused`.

## Limpando o demo

O board veio com cards de exemplo ("Draft migration guide", "Draft release notes" — vindos do manual, não nossos). Apague-os no board (botão direito → deletar) para ver só o NexoSaúde.
3. Colunas por **status**; swimlanes por **prioridade** (opcional, recomendado).
4. Os 7 épicos (`Tasks/E*`) já nascem com `status: Concluído` → coluna Feito no primeiro index.
5. O backlog (`Tasks/Sprint - Backlog.md`) usa `Aberto`; estacione com a tag `#estacionado`, não mudando status.

## Se as colunas vierem com outros nomes

Os status usados aqui (`Aberto`, `Em andamento`, `Concluído`) precisam existir no seu pipeline do Operon. Se o board mostrar coluna "sem status": Settings → Pipelines → renomeie/adicione para bater, ou me peça que eu ajusto os arquivos em lote (5 min).

## Rito sugerido (scrum enxuto)

- **Todo dia**: mover o que mudou de estado no board (o 카드 atualiza o Markdown sozinho).
- **Toda entrega**: marcar feito + anotar validação (analyze/teste/deploy) no corpo do épico.
- **Toda ideia nova**: criar inline task em `Sprint - Backlog.md` com `operonId` novo (`nx-2xx`…), pai e prioridade — nunca sem id.

## Protocolo do agente (para mim, nas próximas sessões)

- Novos todos: `nx-` sequencial, com `{{parentTask:: nx-eN}}`, tags `#nexosaude #area/...` e `dateDue` quando houver prazo.
- Nunca reutilizar `operonId`; nunca editar `Tasks/E*` sem registrar o porquê no corpo.
- Tarefa de código sempre referencia a nota do vault — grafo e board andam juntos.
- `.obsidian/` fora do git (config local); `obsidian/Operon/` versionado normalmente.

## Mapa

- Backlog: [[Sprint - Backlog]]
- Épicos: [[E1 - Plataforma e Assinatura]], [[E2 - Portal e LGPD]], [[E3 - Atendimento e Agenda]], [[E4 - Acesso e Multiclínica]], [[E5 - Cota e Dados]], [[E6 - Docs e Vault]], [[E7 - Avaliações Técnicas]]
- Vault: [[00-index]]
