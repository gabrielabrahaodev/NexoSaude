# Armazenamento privado de documentos — Cloudflare R2 + Worker

Este Worker substitui novos uploads públicos do Cloudinary por objetos em um bucket R2 **sem domínio público**. Ele verifica o Firebase ID token, confere o usuário ativo, o acesso à clínica e a associação paciente/clínica no Firestore. Os arquivos só são entregues por links assinados que expiram em cinco minutos.

> Não publique este Worker nem habilite a URL de produção antes de testar com uma clínica de teste e revisar os domínios permitidos. Nenhum segredo deve ser salvo no Git.

## O que o Worker implementa

- \`POST /v1/files/upload?clinicId=…&patientId=…\`: exige sessão Firebase válida, paciente da clínica, tamanho máximo de 10 MiB e correspondência entre extensão e assinatura binária; grava o objeto no R2 privado e a metadata em \`patients/{patientId}/docs/{documentId}\`. Se a gravação de metadata for recusada, tenta remover o objeto criado.
- \`GET /v1/files/download?clinicId=…&patientId=…&documentId=…\`: revalida a sessão e o escopo, verifica a metadata e emite um link temporário.
- \`GET /v1/files/content?key=…&exp=…&sig=…\`: entrega o objeto apenas com assinatura válida e ainda vigente; inclui \`Cache-Control: private, no-store\` e \`X-Content-Type-Options: nosniff\`.
- \`POST /v1/files/delete\`: revalida sessão, clínica, paciente, metadata e metadata interna do objeto antes de excluir.
- CORS restrito a origens explícitas em \`ALLOWED_ORIGINS\`.

O serviço não aceita URL ou chave arbitrária para deletar arquivo. O caminho do objeto é gerado pelo Worker e fica vinculado à clínica e ao paciente.

## Pré-requisitos

1. Conta Cloudflare com R2 e Workers habilitados.
2. Node.js 20 ou superior no computador de desenvolvimento.
3. Permissão de login no Firebase do projeto \`nexosaude\`.
4. Uma conta de teste e paciente fictício para o primeiro ensaio. Não teste com documentos médicos reais antes da validação final.

## Configuração do R2

No terminal, na raiz do repositório:

\`\`\`powershell
npx wrangler login
npx wrangler r2 bucket create nexosaude-private-documents
\`\`\`

Se o bucket já existir, não o recrie; confirme apenas o nome em R2. Mantenha o bucket **sem domínio público/custom domain** e sem acesso público de leitura.

Entre na pasta do Worker e instale a ferramenta:

\`\`\`powershell
cd workers/private-documents
npm install
npm run check
npm test
\`\`\`

Confira \`wrangler.toml\`. O nome do bucket deve ser exatamente \`nexosaude-private-documents\`. Altere \`ALLOWED_ORIGINS\` para conter a origem real do Hosting usada pelo app, por exemplo \`https://nexosaude.web.app\` e/ou \`https://nexosaude.firebaseapp.com\`. Cada origem é exata, com protocolo e sem barra no final. Se usar domínio próprio, inclua-o também. Não inclua curingas.

## Segredo de assinatura

Gere um segredo aleatório forte e configure-o diretamente no Cloudflare. Não cole o segredo no arquivo TOML, Dart, HTML, GitHub ou Firestore.

\`\`\`powershell
node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"
npx wrangler secret put DOWNLOAD_SIGNING_SECRET
\`\`\`

O segundo comando pede o valor interativamente. Use um segredo de pelo menos 32 caracteres; o recomendado é o hex aleatório de 96 caracteres gerado acima. Guarde-o em um gerenciador de senhas. Se for perdido, configure um novo segredo; links antigos deixarão de validar.

## Deploy do Worker

Ainda em \`workers/private-documents\`:

\`\`\`powershell
npx wrangler deploy
\`\`\`

O comando informa uma URL semelhante a \`https://nexosaude-private-documents.<subdominio>.workers.dev\`. Copie a URL exata, sem acrescentar caminhos de API. Não publique o valor do segredo.

Teste primeiro o endpoint de saúde:

\`\`\`powershell
Invoke-RestMethod https://SUA-URL-DO-WORKER/health
\`\`\`

A resposta esperada contém \`ok: true\`. O endpoint de saúde não verifica a configuração de bucket/segredo; o ensaio autenticado ainda é obrigatório.

## Conectar o app Flutter Web

Na mesma janela do PowerShell, defina a variável com a URL base fornecida pelo Wrangler:

\`\`\`powershell
$env:PRIVATE_FILES_API_URL = "https://SUA-URL-DO-WORKER"
\`\`\`

Volte à raiz do repositório e rode \`deploy.bat\`. O script passa a URL como \`--dart-define\` para o build Web. Se a variável não estiver definida, o build segue, mas a função de envio permanece bloqueada; isso evita enviar dados para um endereço desconhecido.

Para executar build manualmente:

\`\`\`powershell
flutter build web --base-href "/sistema-interno/" --dart-define=PRIVATE_FILES_API_URL=https://SUA-URL-DO-WORKER
\`\`\`

O deploy do Worker é separado do deploy do Firebase Hosting. O \`deploy.bat\` não publica o Worker, não publica Firestore Rules e não contém credenciais Cloudflare.

## Teste funcional obrigatório antes de habilitar em produção

1. Entre com uma conta de teste ativa vinculada a uma clínica de teste.
2. Envie um PDF de teste pequeno. Confirme que o registro apareceu em \`patients/{patientId}/docs\` com \`resourceType: "r2"\`, \`url: "r2://…"\` e \`sizeBytes\` real.
3. Abra o documento: a aplicação deve solicitar link temporário ao Worker e abrir o arquivo.
4. Tente acessar outro paciente alterando os parâmetros, mantendo o token da primeira clínica. A operação deve falhar.
5. Tente enviar um HTML renomeado para PDF, arquivo vazio e arquivo acima de 10 MiB. Todos devem ser rejeitados.
6. Exclua o documento de teste e verifique que tanto o objeto R2 quanto a metadata correspondente desapareceram.
7. Verifique o acesso ao bucket sem autenticação: não pode existir URL pública nem leitura anônima direta do objeto.

Se a criação dos metadados for negada pelas Firestore Rules, **não amplie a regra globalmente**. Confira o usuário, o status ativo e o vínculo com o paciente/clínica. O Worker usa o Firebase ID token do usuário e não contém uma chave administrativa de service account.

## Documentos antigos no Cloudinary

Esta implementação migra **novos uploads** para R2. Os arquivos antigos do Cloudinary não são migrados automaticamente. A tela mantém metadados legados legíveis, mas o app não chama o endpoint destrutivo do Cloudinary nem finge que apagou o binário. A exclusão de uma referência Cloudinary antiga ficará bloqueada até o arquivo ser removido por processo administrativo autenticado.

Antes de decidir a migração, faça inventário somente de leitura de todos os documentos legados (clínica, paciente, ID do documento, presença de \`publicId\`, \`resourceType\`, URL e tamanho). Revise esse inventário com backup e autorização. **Não** faça exclusão em massa, não exponha o API Secret do Cloudinary no cliente e não assuma que todos os objetos antigos são públicos sem verificar o access mode/preset da conta.

## Limitações ainda conhecidas

- As chaves de acesso do Firestore são avaliadas pelas regras existentes. As regras ativas não foram alteradas nem publicadas por este trabalho.
- CORS não substitui autenticação/autorização; o Worker verifica ambas.
- Configure rate limiting no Cloudflare para os endpoints autenticados, monitore erros e defina limites de gasto/alertas.
- O link de leitura é uma credencial temporária que pode ser compartilhada enquanto estiver válido; ele expira em cinco minutos.
- Nenhum arquivo, segredo, bucket ou deploy de produção foi criado/alterado automaticamente por este repositório.
