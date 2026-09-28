# Pluma — angular-pluma-pwa

> Semana(s): 7, 10 · Pilar: **Dashboard** · Teste unitário: **Vitest** · Milestone(s): `m1-pluma, m2-perf`
> Repo público: [github.com/zecki1/angular-pluma-pwa](https://github.com/zecki1/angular-pluma-pwa)

## Objetivo de entrevista

levar um app financeiro offline-first com Service Worker, cache e instalação (A2HS)

## Stack

- **Angular 22** — standalone, signals, zoneless, OnPush por padrão
- **Supabase** — Postgres + Auth + RLS (projeto compartilhado `angular-portfolio`)
- **Service Worker** + **Workbox** (cache, sync em background, A2HS) · **IndexedDB** (fila offline)
- **ECharts** (dashboards) · **Vercel** — build estático (sem cold start, sempre online)

## Fluxo de trabalho (Git)

Ambientes preservados em **português brasileiro** (commits, PRs, issues, CI).

```
main      → produção (build estático; nunca push direto)
homolog   → validação/release de PRs (staging)
develop   → integração diária (merges das branches feat/*)
feature   → feat/<assunto> + PR para develop (boas práticas de código limpo)
```

- **Commits:** `feat:`, `fix:`, `test:`, `docs:`, `design:`, `ops:`, `backend:` (conventional commits)
- **PRs:** sempre via **pull request template**; revisados e mergeados por milestone
- **main:** protegida — merge somente via PR de `homolog`
- Rastreabilidade com issues, labels (`feat/test/design/ops/backend`), milestones e releases

## Rodando localmente

```bash
npm install
npm start            # ng serve
npm test             # unitário (Vitest)
npm run test:ci      # unitário em modo CI (coverage)
npm run e2e          # Playwright (local)
npm run e2e:ci       # Playwright (CI)
npm run build        # ng build
npm run analyze      # source-map-explorer (análise de bundle)
```

## Ambiente (Supabase)

Variáveis em `.env` (nunca commitadas):

```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_ROLE=demo
CLARITY_PROJECT_ID=
```

Dados usados: **`profiles`**, **`accounts`**, **`transactions`**, **`favorites`** e
**`products`** — as tabelas da Sem 3 (Ledger) com o que a Sem 7 acrescenta para o
offline. Schema, RLS, seed e as decisões de segurança em
[`supabase/`](./supabase/README.md), aplicados no projeto compartilhado
`angular-portfolio`.

## Decisão de teste: Vitest

> Por que **Vitest** neste projeto? (§2.2 do planejamento) A Sem 7 é a semana do
> dashboard financeiro: regra de categorização, cálculo de saldo, agrupamento por mês e
> a fila de sync offline. É lógica pura e determinística — não há animação para medir nem
> WebGL para renderizar. Vitest roda em Node sem browser, o que dá o ciclo de feedback
> mais curto das 12 semanas, e o `@vitest/coverage-v8` mede por linha sem adistorção do
> instrumentador do Karma.
>
> **O que o Vitest não cobre aqui, e o que cobre no lugar:** o service worker é a
> superfície de risco real desta semana, e unit test não a alcança. O que substitui isso
> é E2E com Playwright em contexto offline (`context.setOffline(true)`) verificando
> leitura do cache, escrita na fila e reenvio — que testa o comportamento, não a
> implementação. A regra do rodízio se mantém: showcase (1, 5, 8, 11) pede Karma,
> dashboard/lógica (3, 4, 6, 7, 10) pede Vitest.

## Estado atual (bloco de fim de semana)

Esta entrega cobre **somente o backend** — schema, RLS, seed e documentação. O front do
Pluma ainda é o scaffold do Angular 22, sem `src/`:

- [x] **Supabase**: `0001_schema.sql`, `0002_rls.sql` e `seed.sql` prontos para o
      projeto `angular-portfolio`
- [ ] Build/lint/typecheck — bloqueado até existir front
- [ ] Unit (Vitest) com cobertura ≥ 80% — bloqueado até existir front
- [ ] E2E Playwright + axe — bloqueado até existir front
- [ ] Lighthouse ≥ 90 — bloqueado até existir front
- [ ] Responsivo (mobile/tablet/desktop) — bloqueado até existir front
- [x] README com decisões de RLS e o que falta para fechar a Sem 7
- [ ] PR revisado + merged + release por milestone

O SQL foi revisado e está idempotente (`IF NOT EXISTS` em todo canto), mas **não foi
executado**: não há `psql`, `docker` nem Supabase CLI neste ambiente, e o projeto
hospedado não tem credencial configurada. A primeira aplicação é no SQL Editor do
`angular-portfolio`, e é ali que os `alter table ... add column if not exists` das
tabelas da Sem 3 vão ser conferidos — ver "O que a Sem 7 acrescenta sobre a Sem 3" em
[`supabase/README.md`](./supabase/README.md).

## O que aprendi

**RLS decide linha, não coluna** — e é por isso que autoelevação de `role` é problema
de trigger, não de policy. A policy "profiles: edita a si mesmo" precisa existir para o
dono atualizar nome e avatar, e como consequência dela o `UPDATE profiles SET
role='admin'` passa: os dois `with check` olham só o `id`. O papel `admin` é justamente
o que concede `accounts: admin`, ou seja, leitura das contas dos outros. A trava ficou
num `before update` que só age quando `role` muda e quem chama não é admin — e é
`SECURITY DEFINER` com `search_path` fixo, senão o `current_role()` é resolvido no
contexto de quem chamou.

**Soft delete é exigência do offline, não preferência de estilo.** Excluir conta é o
único *destructive sync* do app. Com delete físico, um cliente que ficou offline durante
a exclusão ressuscita a conta no próximo push — o `deleted_at` vira tombstone, e a
policy de `transactions` passa a exigir `deleted_at is null` para que conta morta não
arraste extrato. O índice parcial (`where deleted_at is null`) existe porque é
exatamente a query que o PWA abre primeiro.

**`CREATE TABLE IF NOT EXISTS` é um no-op silencioso.** Declarar `updated_at` e
`deleted_at` no `create table` não adiciona nada a uma base compartilhada que já tem
`accounts` da Sem 3 — a tabela existe, o statement pula, e a falha só apareceria no
primeiro insert da fila offline, em produção. Os `alter table ... add column if not
exists` não são redundância: são o que faz a migration funcionar no ambiente real.

**O seed automático não pode criar dados de usuário.** `accounts` e `transactions`
pertencem a um profile em `auth.users`, e as policies amarram tudo em `auth.uid()`. Um
seed que criasse usuário de verdade passaria a depender de `service_role` versionado no
repo. Fica só o catálogo público no seed, e o bloco de demo comentado com o caminho
manual.

## Screenshots

_(pendente — o front ainda não existe)_

## Microsoft Clarity (mapa de calor)

Integração documentada em [`docs/clarity-integracao.md`](./docs/clarity-integracao.md).
O snippet só é ativado quando `CLARITY_PROJECT_ID` está definida.

## Permanência online

Estratégia zero-standby documentada em [`docs/manter-online.md`](./docs/manter-online.md).

---

## Base navegavel (Semana 7)

Scaffold Angular 22 standalone + zoneless, com shell roteado, Tailwind 4 e o
mesmo codegen de ambiente usado no `vice-district`. Nenhum build foi executado
neste PR de proposito — a validacao de build ficou para o fim do dia.

### Rodar local

```bash
npm install          # o postinstall roda `npm run env` e gera o ambiente
cp .env.example .env # preencha VITE_SUPABASE_ANON_KEY
npm start            # http://localhost:4200
```

### Scripts

| script          | o que faz                                                        |
| --------------- | ---------------------------------------------------------------- |
| `npm run env`   | gera `src/environments/ambiente.local.ts` a partir do `.env`     |
| `npm start`     | `ng serve`                                                        |
| `npm run build` | build de producao (budget inicial: warning 350 kB / erro 500 kB)  |
| `npm test`      | unit (Vitest)                                                     |
| `npm run test:ci` | unit em modo nao interativo + coverage                         |
| `npm run lint`  | ESLint + angular-eslint                                           |

### Rotas

- `/login` — Login
- `/dashboard` — Dashboard
- `/transacoes` — Transacoes
- `/configuracoes` — Configuracoes

### Segredos

`.env` e `src/environments/ambiente.local.ts` sao gitignored. O que vai para o
repo e apenas o `.env.example`, com placeholders. A `service_role` key nunca
entra no front — a protecao real e o RLS.
