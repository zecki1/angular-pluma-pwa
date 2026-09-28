-- Pluma PWA (Semana 7) — seed do catálogo público.
--
-- Rodar depois de 0001_schema.sql e 0002_rls.sql, no SQL Editor do projeto
-- `angular-portfolio` ou via `supabase db seed`.
--
-- Escopo: só `products`, e é proposital.
--
-- `accounts` e `transactions` NÃO são semeados. Eles pertencem a um profile
-- real em auth.users, e as policies de RLS amarram tudo em auth.uid().
-- Semeá-los exigiria criar um usuário de verdade no Auth — senão a FK de
-- profiles falha — e o seed passaria a depender de um segredo. A alternativa
-- correta para ambiente de demo está comentada no fim deste arquivo.

-- ---------------------------------------------------------------------------
-- Catálogo público
--
-- Idempotente por nome, apoiado no índice único products_name_uniq criado em
-- 0001_schema.sql. O `on conflict (name) do nothing` é o que permite rodar o
-- seed quantas vezes for, inclusive em CI.
-- ---------------------------------------------------------------------------

insert into public.products (name, price, description, image_url, active)
values
  ('Pluma Starter',     0.00,  'Plano free com cache offline do catálogo e 1 conta.', null, true),
  ('Pluma Essencial',  19.90,  '3 contas, 12 meses de histórico e exportar CSV.',    null, true),
  ('Pluma Pro',        49.90,  'Contas ilimitadas, categorias sem limite e metas.', null, true),
  ('Pluma Equipe',    149.90,  'Perfis compartilhados e reconciliação por device_id.', null, true),
  -- Inativo de propósito: exercita a policy "products: leitura pública", que
  -- filtra por active, e deixa um item invisível para o cache do service
  -- worker revalidar.
  ('Pluma Legacy',     99.00,  'Preço congelado para os 50 primeiros clientes.',     null, false)
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Dados de demonstração de um usuário real (opcional, manual)
--
-- NÃO faz parte do seed automático. Para um usuário de teste:
--
--   1. Crie o usuário no Supabase Auth (Authentication > Users > Add user) e
--      confirme o e-mail. handle_new_user() cria a linha em profiles.
--   2. Pegue o id em auth.users e rode o bloco abaixo, com service_role no
--      SQL Editor — a anon key não passa pelas policies, porque não existe
--      sessão auth.uid() no SQL Editor.
--
-- insert into public.accounts (profile_id, name, type, balance, currency)
-- values ('<UUID_DO_AUTH>', 'Conta corrente', 'conta_corrente', 4250.90, 'BRL'),
--        ('<UUID_DO_AUTH>', 'Poupança',       'poupanca',      12800.00, 'BRL');
--
-- insert into public.transactions (account_id, type, description, amount, direction, category, settled_at)
-- select a.id, t.type, t.description, t.amount, t.direction, t.category, t.settled_at
-- from public.accounts a
-- join (values
--   ('pix',        'Mercado do bairro',        284.90, 'out', 'mercado',     now() - interval '1 day'),
--   ('credito',    'Salário',                 7200.00, 'in',  'renda',       now() - interval '3 days'),
--   ('debito',     'Assinatura de streaming',   55.90, 'out', 'lazer',       now() - interval '5 days'),
--   ('investimento','Renda fixa',              150.00, 'in',  'investimento', now() - interval '7 days')
-- ) as t(type, description, amount, direction, category, settled_at)
--   on true
-- where a.profile_id = '<UUID_DO_AUTH>';
