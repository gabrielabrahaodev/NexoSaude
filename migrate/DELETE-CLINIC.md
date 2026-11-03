# Exclusão administrativa de clínica bloqueada/expirada

Use este procedimento apenas quando a cascata de exclusão dentro do sistema Web for negada pelas Firestore Rules (por exemplo, clínica bloqueada pelo Master ou com trial vencido). O script usa Admin SDK e por isso contorna as Rules; trate-o como uma operação destrutiva privilegiada.

## Pré-requisitos

1. Faça backup/exportação dos dados relevantes.
2. Na raiz do projeto, confirme o projeto Firebase e que a credencial local migrate/new-key.json tem project_id nexosaude. A chave nunca deve ser enviada ao Git ou compartilhada.
3. Instale as dependências de migração: cd migrate && npm ci && cd ..

## 1. Simulação obrigatória (não escreve)

```bash
node migrate/delete-clinic.js --clinic ID_DA_CLINICA
```

Revise o ID/nome e todas as contagens. O modo padrão é somente leitura. O preflight também varre `patients/{id}/docs` e lista metadados que apontam para binários do Cloudinary; o script interromperá o `--apply` antes de qualquer escrita se encontrar esses arquivos.

## 2. Exclusão efetiva

Somente depois de confirmar que o backup e o relatório estão corretos:

```bash
node migrate/delete-clinic.js --clinic ID_DA_CLINICA --apply --confirm-delete ID_DA_CLINICA
```

O ID deve aparecer duas vezes, exatamente igual. A operação desvincula contas de usuário (não remove suas contas de autenticação), exclui registros operacionais com clinicId correspondente, remove espelhos públicos/portal e apaga recursivamente as subcoleções de pacientes e da clínica.

## Limitações e recuperação

- A pré-verificação ocorre antes das escritas, mas a exclusão é composta por várias operações e pode ficar parcialmente concluída se houver falha de rede ou permissão IAM durante o processo. A rotina é idempotente para exclusões já realizadas; execute novamente o dry-run antes de qualquer repetição.
- Solicitações de trial são mantidas como histórico.
- Esta rotina não apaga binários do Cloudinary. Se o preflight listar algum caminho `patients/{patientId}/docs/{documentId}`, remova primeiro esse arquivo usando `migrate/delete-cloudinary-document.js` em dry-run e depois `--apply --confirm-delete CLINICA/PACIENTE/DOCUMENTO`. Refaça o dry-run da clínica; a cascata só prossegue quando não houver mais metadados remotos.
- Nunca rode esse script por rotina nem sem backup e revisão humana do relatório.
