# Prontuário — referência image(20261103-184637).png

Barra tonal compacta com Todos/Evoluções/Cancelamentos/Procedimentos, contagens reais, ordenação cronológica alternável e Novo Registro. Cards com faixa por tipo, data/autor e descrição integral selecionável. Cancelamentos identificados por título registrado ou attendanceStatus missed; cobranças permanecem em Todos como administrativas, sem contá-las como evolução. Procedimentos filtra vínculo explícito treatmentId; não infere realização nem diagnóstico.

Nos cancelamentos, dentistName legado é apresentado como operador, não como responsável clínico. Evoluções mostram Profissional do registro, sem afirmar validação/assinatura médica. Descrições antigas mantidas sem parsing destrutivo. Anexos e números de orçamento não são inventados; não há vínculo binário padronizado no registro antigo. Badge de procedimento somente com treatmentId.

Novo/editar mantém formulário existente e permite evolução geral sem plano ativo. Streams de registros e plano reutilizados; salvar impede duplo clique e mudança de contexto, preserva rascunho em erro. Editar não substitui autor/data originais: grava editedBy/editedAt. Excluir requer confirmação e mantém guard de unidade.

Validação: diff --check e conferência do patch. Quatro cenários de widget adicionados para temas/larguras, filtros, operador e ações. Flutter/build/renderização não executados no ambiente por falta de SDK. Conferir autenticado em 390 e 1200px, claro/escuro, registros legados, cancelar/editar/excluir e ausência/erro de leitura. Nenhuma migração, Rules, índices ou dados alterados.
