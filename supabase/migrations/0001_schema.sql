-- Pluma PWA (Semana 7) — espelho das tabelas da Sem 3 (Ledger) + cache offline.
--
-- Aplicar no projeto Supabase compartilhado `angular-portfolio` (§4 do planejamento).
-- Idempotente: pode ser reaplicado sem efeito colateral.
--
-- Diferença em relação à Sem 3: o Pluma é um PWA instalável que precisa abrir
-- com sinal ruim. O schema-base da Sem 3 já é suficiente para os dados, mas
-- falta o que sustenta o modo offline, que é o requisito real da Sem 7:
--
--   1. `updated_at` em transactions/accounts. O service worker revalida por
--      "last-write-wins" e precisa saber de quando é cada linha para decidir
--      entre o cache e a rede. Sem carimbo, ele só consegue ignorar a rede.
--   2. `deleted_at` em accounts. Excluir conta é o único "destructive sync" do
--      app; com delete físico, um cliente offline que não recebeu o evento
--      ressuscita a conta no próximo push. Soft delete + tombstone resolve.
--   3. `products.synced_at`. O catálogo é o único dado público lido por
--      anônimo, e é o que o cache preenche primeiro no primeiro acesso.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- profiles — mesma forma do schema-base §4.2. Só o trigger de criação está
-- documentado aqui, porque é o que garante a linha de profile existir antes
-- de qualquer insert em accounts/favorites (as duas têm FK para profiles).
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user'
    check (role in ('admin','analyst','user','viewer')),
  name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- accounts / transactions — dados do Ledger da Sem 3, com os carimbos de sync
-- ---------------------------------------------------------------------------

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  type text check (type in ('conta_corrente','poupanca','cartao_credito','investimentos')),
  balance numeric(14,2) not null default 0,
  currency text not null default 'BRL',
  created_at timestamptz not null default now(),
  -- Sem 7: sync offline.
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  type text check (type in ('pix','ted','debito','credito','investimento','pagamento')),
  description text not null,
  amount numeric(14,2) not null,
  direction text check (direction in ('in','out')),
  category text,
  settled_at timestamptz not null default now(),
  -- Sem 7: sync offline.
  updated_at timestamptz not null default now(),
  -- O upload do PWA é best-effort: a fila local só sobe quando há rede, e a
  -- partir daí o servidor precisa de um relógio confiável para decidir se o
  -- que chegou é mais novo que o que já está na base (last-write-wins).
  device_id text
);

-- Colunas da Sem 7 em tabelas que a Sem 3 já criou.
--
-- `CREATE TABLE IF NOT EXISTS` é um no-op silencioso quando a tabela existe:
-- declararem as colunas acima NÃO as adiciona a uma base compartilhada que já
-- tem accounts/transactions. Sem estes ALTER, o Pluma subiria com
-- updated_at/deleted_at/device_id inexistentes e a falha só apareceria no
-- primeiro INSERT da fila offline — em produção.
alter table public.accounts     add column if not exists updated_at timestamptz not null default now();
alter table public.accounts     add column if not exists deleted_at timestamptz;
alter table public.transactions add column if not exists updated_at timestamptz not null default now();
alter table public.transactions add column if not exists device_id text;
alter table public.products     add column if not exists synced_at  timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- favorites — igual ao schema-base; o Pluma só usa para o "salvar para ler
-- depois" do catálogo, então o unique (profile_id, target_type, target_id)
-- do §4.2 já evita duplicata no reenvio da fila offline.
-- ---------------------------------------------------------------------------

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_type text check (target_type in ('product','project','post','lead')),
  target_id text not null,
  created_at timestamptz not null default now(),
  unique (profile_id, target_type, target_id)
);

-- ---------------------------------------------------------------------------
-- products — catálogo público; é o que o cache do service worker preenche
-- ---------------------------------------------------------------------------

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric(14,2) not null,
  description text,
  image_url text,
  active boolean not null default true,
  -- Sem 7: o cliente compara para saber se o catálogo do cache ainda vale.
  synced_at timestamptz not null default now()
);

-- Índices do §4.2, mais os dois que a Sem 7 precisa e que não existiam.
create index if not exists transactions_account_id_idx   on public.transactions(account_id);
create index if not exists transactions_settled_at_idx   on public.transactions(settled_at desc);
create index if not exists accounts_profile_id_idx       on public.accounts(profile_id);
create index if not exists favorites_profile_id_idx      on public.favorites(profile_id);

-- Unique por nome: o seed precisa de um alvo para o ON CONFLICT, e catálogo
-- com dois "Pluma Pro" quebraria o card de upgrade do PWA.
--
-- O nome products_name_key é o mesmo que a Sem 5 (Aurum) usa, de propósito:
-- o projeto é compartilhado, e dois índices únicos em (name) só gastariam
-- escrita. Com IF NOT EXISTS, quem criar por último não cria nada.
create unique index if not exists products_name_key on public.products (name);

-- Índice parcial: o app só sincroniza contas vivas. Sem ele, o "WHERE
-- deleted_at IS NULL" do cliente vira full scan conforme as Soft Deletes
-- acumulam, e é justamente a tabela que o PWA abre em primeiro.
create index if not exists accounts_vivos_idx
  on public.accounts (profile_id)
  where deleted_at is null;

-- Índice parcial equivalente para a tela de extrato.
create index if not exists transactions_recentes_idx
  on public.transactions (account_id, settled_at desc)
  where account_id is not null;

-- updated_at precisa ser automático. A Sem 3 escrevia updated_at na aplicação,
-- o que é frágil: qualquer INSERT que esqueça o campo grava epoch e a fila
-- offline nunca mais sobe.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists accounts_touch_updated_at on public.accounts;
create trigger accounts_touch_updated_at
  before update on public.accounts
  for each row execute function public.touch_updated_at();

drop trigger if exists transactions_touch_updated_at on public.transactions;
create trigger transactions_touch_updated_at
  before update on public.transactions
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Profile criado junto com o signup.
--
-- Sem este trigger, accounts e favorites não têm para onde apontar: as duas
-- tabelas têm FK para profiles(id), e um usuário recem-criado no Auth com
-- profile ausente receberia violação de FK no primeiro insert — erro que só
-- aparece em produção, porque em dev o usuário já estava logado antes.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
