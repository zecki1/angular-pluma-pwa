# Supabase — Pluma PWA

Tabelas usadas por este app: **`profiles`**, **`accounts`**, **`transactions`**,
**`favorites`** e **`products`** — as mesmas da Sem 3 (Ledger), com o que o modo
offline da Sem 7 acrescenta.

As migrations são aplicadas no projeto Supabase **compartilhado**
`angular-portfolio`, que atende todas as apps do roadmap (§4 do planejamento). Não
existe um Supabase por app: o que separa as bases de dados são as policies, e neste
caso a separação é por `profile_id` (dono dos dados), não por `project_slug` (como nas
semanas de vitrine).

## Arquivos

| Arquivo | O que faz |
|---|---|
| `migrations/0001_schema.sql` | As 5 tabelas, os carimbos de sync offline, índices parciais, trigger de `updated_at` e o trigger que cria `profiles` no signup |
| `migrations/0002_rls.sql` | RLS por dono, policy pública só no catálogo, e o trigger anti-autoelevação de `role` |
| `seed.sql` | Catálogo público (idempotente). Dados de usuário ficam comentados, com o motivo |

## Aplicar

```bash
# 1) no SQL Editor do projeto angular-portfolio, na ordem:
#    migrations/0001_schema.sql
#    migrations/0002_rls.sql
#    seed.sql
#
# 2) o service worker precisa de sync do IndexedDB e do Workbox:
#    (configuração de front, fora deste bloco de backend)
```

## O que a Sem 7 acrescenta sobre a Sem 3

O schema da Sem 3 (Ledger) já dava conta de tudo que é *online*. O que faltava para
esta semana é o que sustenta o app **com sinal ruim**:

- **`updated_at` em `accounts` e `transactions`.** A fila offline do PWA resolve
  conflito por last-write-wins; sem carimbo de tempo, o cliente não tem como decidir
  entre o que está no cache e o que veio da rede.
- **`deleted_at` em `accounts` (soft delete).** Excluir conta é o único *destructive
  sync* do app. Com delete físico, um cliente que estava offline durante a exclusão
  ressuscita a conta no próximo push — o tombstone evita isso.
- **`device_id` em `transactions`.** Identifica a origem de um lote reenviado, para
  depurar conflito sem expor nada ao cliente.
- **`synced_at` em `products`.** O service worker compara para saber se o catálogo em
  cache ainda vale antes de revalidar.
- **Índices parciais `where deleted_at is null`.** São as queries que o PWA abre
  primeiro; sem o índice parcial, o `WHERE deleted_at IS NULL` do cliente vira full scan
  conforme os soft deletes acumulam.

## Decisões de RLS

- **Só `products` é público**, e filtrado por `active`. A sessão anônima recebe policy
  em `products` e em nenhuma outra tabela — inclusive não em `leads`, que existe no
  schema compartilhado e cujo insert é público para as semanas de vitrine. Aqui a
  ausência de policy é a proteção: sem policy, o RLS nega.
- **A posse de `transactions` vem de `accounts`.** A tabela não tem `profile_id`; a
  policy correlaciona `account_id in (select id from accounts where profile_id =
  auth.uid())`. É a técnica do §4.2, com o `deleted_at is null` acrescentado para que
  conta morta não arraste extrato.
- **Anti-autoelevação por trigger, não por policy.** RLS decide *linha*, não *coluna*.
  A policy "profiles: edita a si mesmo" precisa existir (o dono tem que atualizar nome e
  avatar), e como consequência dela permitiria `UPDATE profiles SET role='admin'`. Isso
  daria a quem o papel que concede `accounts: admin` — leitura das contas dos outros. O
  trigger `prevent_role_self_promotion` só bloqueia quando `role` muda e quem chama não
  é admin.
- **`current_role()` é `SECURITY DEFINER`**, porque a policy de `profiles` consulta
  `profiles`; sem o definer isso entra em recursão de RLS.
- **O trigger `handle_new_user` cria a linha em `profiles` no signup.** Sem ele, um
  usuário novo receberia violação de FK no primeiro insert em `accounts` — erro que só
  apareceria em produção, porque em dev o usuário já estava logado.

## Por que o seed não cria contas

`accounts` e `transactions` pertencem a um profile real em `auth.users`, e as policies
amarram tudo em `auth.uid()`. Um seed automático precisaria criar um usuário de verdade
no Auth — a FK de `profiles` falha sem ele — e passaria a depender de um segredo
(service_role) versionado. O bloco de dados de demonstração está comentado no fim do
`seed.sql`, com o caminho correto (criar o usuário no Auth, rodar o SQL com
`service_role`).

## O que falta para fechar a Sem 7

O bloco de backend está completo no que é schema, RLS e seed. Falta, na parte de
front/serviço:

- `handle_new_user` assumindo `raw_user_meta_data->>'name'`: confirmar o shape do
  metadata do projeto Supabase real.
- A fila offline do service worker (IndexedDB + Workbox `BackgroundSync`), que é quem
  usa `device_id` e faz o last-write-wins com `updated_at`.
- A limpeza de `deleted_at` (job periódico) — o tombstone não expira sozinho.
