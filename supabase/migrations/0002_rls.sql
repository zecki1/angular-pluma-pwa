-- Pluma PWA (Semana 7) — Row Level Security (§4.3 do planejamento).
--
-- Esta é a parte que o PWA endurece. Uma app comum só precisa que o dono veja o
-- que é dele. O Pluma precisa de mais:
--
--   1. Só o catálogo é público. accounts, transactions, favorites e profiles
--      não têm nenhuma policy para sessão anônima — dados financeiros não
--      podem responder a um curl sem JWT. products é a única exceção, e mesmo
--      assim filtrada por active.
--   2. O usuário é dono dos próprios dados e só dos próprios. Toda policy de
--      leitura/escrita passa por profile_id = auth.uid() — nunca por um
--      project_slug, como nas semanas de vitrine. Não existe "conteúdo
--      compartilhado" para vazar.
--   3. O offline muda o formato do insert, não a permissão. A fila local do
--      PWA sobe lotes com device_id e updated_at do cliente, mas a policy
--      continua checando o dono. Aceitar um lote anônimo porque "vem do
--      service worker" seria transformar o cache em backdoor.
--   4. Ninguém promove o próprio role (trigger no fim do arquivo).

alter table public.profiles    enable row level security;
alter table public.accounts    enable row level security;
alter table public.transactions enable row level security;
alter table public.favorites   enable row level security;
alter table public.products    enable row level security;

-- Helper: role do usuário autenticado, lido do próprio profile.
-- SECURITY DEFINER evita recursão de RLS (a policy de `profiles` consulta `profiles`).
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- profiles — cada um vê e edita só a si mesmo
-- ---------------------------------------------------------------------------

drop policy if exists "profiles: vê a si mesmo" on public.profiles;
create policy "profiles: vê a si mesmo"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "profiles: admin vê todos" on public.profiles;
create policy "profiles: admin vê todos"
  on public.profiles for select
  using (public.current_role() = 'admin');

drop policy if exists "profiles: edita a si mesmo" on public.profiles;
create policy "profiles: edita a si mesmo"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- A policy acima tem with check (id = auth.uid()), mas isso NÃO impede
-- autoelevação: "UPDATE profiles SET role='admin' WHERE id=<eu>" passa no
-- using e no check, porque os dois só olham o id. Quem impedir isso é
-- prevent_role_self_promotion, no fim deste arquivo. As policies cuidam de
-- *quem* pode escrever; o trigger cuida *no que* se pode escrever.
drop policy if exists "profiles: admin edita qualquer" on public.profiles;
create policy "profiles: admin edita qualquer"
  on public.profiles for update
  using (public.current_role() = 'admin');

-- ---------------------------------------------------------------------------
-- accounts — dono e admin/analyst
-- ---------------------------------------------------------------------------

drop policy if exists "accounts: dono" on public.accounts;
create policy "accounts: dono"
  on public.accounts for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "accounts: admin" on public.accounts;
create policy "accounts: admin"
  on public.accounts for all
  using (public.current_role() in ('admin','analyst'))
  with check (public.current_role() in ('admin','analyst'));

-- ---------------------------------------------------------------------------
-- transactions — o dono é herdado via accounts, não via transactions
-- ---------------------------------------------------------------------------

-- transactions não tem profile_id: a posse vem da conta. Uma subquery
-- correlacionada é o preço disso, e é a mesma técnica que o §4.2 usa.
drop policy if exists "transactions: dono" on public.transactions;
create policy "transactions: dono"
  on public.transactions for all
  using (
    account_id in (
      select id from public.accounts
      where profile_id = auth.uid() and deleted_at is null
    )
  )
  with check (
    account_id in (
      select id from public.accounts
      where profile_id = auth.uid() and deleted_at is null
    )
  );

drop policy if exists "transactions: admin" on public.transactions;
create policy "transactions: admin"
  on public.transactions for all
  using (public.current_role() in ('admin','analyst'))
  with check (public.current_role() in ('admin','analyst'));

-- ---------------------------------------------------------------------------
-- favorites — dono e admin
-- ---------------------------------------------------------------------------

drop policy if exists "favorites: dono" on public.favorites;
create policy "favorites: dono"
  on public.favorites for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "favorites: admin" on public.favorites;
create policy "favorites: admin"
  on public.favorites for all
  using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

-- ---------------------------------------------------------------------------
-- products — leitura anônima é o que o cache do service worker preenche
-- ---------------------------------------------------------------------------

-- A policy do §4.2 filtra por active = true. Aqui o Pluma precisa de
-- synced_at visível junto, senão o cache não consegue decidir se o catálogo
-- guardado ainda é válido — e é esse par (active, synced_at) que define a
-- janela de revalidação do PWA.
drop policy if exists "products: leitura pública" on public.products;
create policy "products: leitura pública"
  on public.products for select
  using (active);

drop policy if exists "products: admin escreve" on public.products;
create policy "products: admin escreve"
  on public.products for all
  using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

-- ---------------------------------------------------------------------------
-- Anti-autoelevação
--
-- RLS decide *linha*, não *coluna*. A policy "profiles: edita a si mesmo"
-- permite legitimately que o dono atualize o próprio profile — nome, avatar.
-- O efeito colateral é que ela também permite gravar `role`, porque nenhuma
-- policy Postgres sabe dizer "esta coluna, exceto esta".
--
-- Se isso passar, qualquer usuário vira admin com um UPDATE e passa a ler as
-- contas dos outros via "accounts: admin". Como admin é justamente o papel que
-- concede leitura sobre dados financeiros de terceiros, a trava vai em trigger.
--
-- SECURITY DEFINER + search_path fixo: o trigger roda com privilégio de quem o
-- criou, então current_role() precisa ser resolvido antes de qualquer coisa
-- que o caller controle.
-- ---------------------------------------------------------------------------

create or replace function public.prevent_role_self_promotion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Só interessa quando o role muda de fato; o resto dos updates passa reto.
  if new.role is distinct from old.role then
    if public.current_role() <> 'admin' then
      raise exception 'promocao de role negada: apenas admin altera role (id=%)', old.id
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_self_promotion on public.profiles;
create trigger profiles_prevent_role_self_promotion
  before update on public.profiles
  for each row execute function public.prevent_role_self_promotion();
