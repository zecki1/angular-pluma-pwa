# Case study — Pluma

> App financeiro **offline-first** em Angular 22. Pilar **Dashboard** (Semanas 7 e 10 do roadmap) ·
> teste unitário em **Vitest** · demo pública no GitHub Pages.

## Contexto

O roadmap de 12 semanas tem um pilar de **dashboard/lógica** para cada app financeiro. O Pluma é o
app que leva esse pilar ao extremo: além de consolidar saldo e extrato, ele precisa **funcionar
offline** — Service Worker, cache, fila de sincronização e instalação na tela inicial (A2HS). É o
mesmo domínio do Ledger (Semana 3), mas com a superfície de risco real de um PWA: o que acontece
quando a rede some no meio de um lançamento.

O projeto usa o **Supabase compartilhado do roadmap** (`angular-portfolio`) como Postgres + Auth +
RLS, com a anon key no front (o RLS é a proteção real; a `service_role` nunca entra no bundle).

## Desafio

1. **Offline-first de verdade.** Um app financeiro que perde dados quando o Wi-Fi cai não serve.
   Escrever no cache e reenviar depois (fila) é mais difícil que ler do cache e desistir.
2. **Conflito e exclusão.** Sync bidirecional sem tombstones ressuscita contas excluídas — soft
   delete (`deleted_at`) e índice parcial não são preferência de estilo, são exigência do offline.
3. **RLS não decide coluna.** A policy "profiles: edita a si mesmo" permite `UPDATE role='admin'`;
   a trava precisa ser trigger `before update`, `SECURITY DEFINER` com `search_path` fixo.
4. **Testar o intestével.** O Service Worker não aparece em unit test — a verificação que importa é
   E2E em contexto offline (`context.setOffline(true)`), testando comportamento, não implementação.
5. **Entregar acessível.** PWA é usado no celular, muitas vezes por leitor de tela. Zero violações
   graves/críticas é requisito, não bônus.

## Solução

- **Scaffold Angular 22** standalone + zoneless + signals, Tailwind 4, shell roteado
  (`login` / `dashboard` / `transacoes` / `configuracoes`) e skip-link para o conteúdo.
- **Supabase** como backend único compartilhado, com **fallback demo**: sem `.env` o app sobe e
  avisa — nenhuma tela quebra por falta de credencial.
- **Codegen de ambiente** (`scripts/gerar-ambiente.mjs`): o builder `@angular/build:application`
  não implementa `import.meta.env`, então o contrato `VITE_*` é gerado em
  `src/environments/ambiente.local.ts` (gitignored) no `postinstall`/`prestart`/`prebuild`/`pretest`.
- **Qualidade guardada por CI**: lint → build → unit (Vitest + coverage) → E2E (Playwright + axe) →
  Lighthouse; e o bot diário de testes com o browser do Playwright instalado.
- **E2E em dois eixos**: varredura de acessibilidade (axe, WCAG 2.0/2.1 A+AA) e baselines de print
  (desktop/mobile) que alimentam este README.

## Métricas

| Métrica | Resultado |
|---------|-----------|
| Unit (Vitest) | 6/6 passando |
| Cobertura | 76,7% statements · 69,0% branches · 78,6% lines |
| E2E (Playwright) | ver `README.md` — a11y (4 telas) + 8 baselines |
| Acessibilidade (axe) | 0 violações graves/críticas |
| Bundle inicial | 472,8 kB (≈115,0 kB transfer) |
| ESLint | 0 erros |

## O que aprendi

**Offline não é cache, é fila.** Guardar resposta em cache é fácil e não resolve nada: o valor do
app está na *escrita* offline e no reenvio. A fila precisa de idempotência (chave do cliente por
lançamento), senão o reenvio duplica a transação.

**Soft delete é o preço do bidirecional.** Com delete físico, um cliente que ficou offline durante
a exclusão ressuscita a conta no próximo push. O `deleted_at` vira tombstone, e as queries do extrato
passam a exigir `deleted_at is null` — com índice parcial exatamente na query que o PWA abre primeiro.

**`CREATE TABLE IF NOT EXISTS` é um no-op silencioso.** Numa base compartilhada que já tem `accounts`
da Semana 3, declarar colunas novas no `create table` não adiciona nada. Os
`alter table ... add column if not exists` é que fazem a migration funcionar no ambiente real.

**Codegen de ambiente é a resposta certa no Angular.** O esbuild do `@angular/build` não tem
`import.meta.env`; gerar um módulo TS antes do build mantém o contrato `VITE_*` sem colocar chave
dentro do repo.

**Testar o que não roda em unit test.** O Service Worker só se prova em E2E offline. A escolha de
Vitest para o unit (lógica pura, rápida) e Playwright para o comportamento offline é a divisão que
deixa o feedback curto sem perder a cobertura que importa.

## Links

- Demo: https://zecki1.github.io/angular-pluma-pwa/
- Repo: https://github.com/zecki1/angular-pluma-pwa
