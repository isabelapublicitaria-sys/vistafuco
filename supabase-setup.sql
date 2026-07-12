-- Vista Fuço CRM — setup do banco no Supabase
-- Rode isso uma vez em: Supabase Dashboard > SQL Editor > New query > Run

create table if not exists crm_config (
  id integer primary key default 1,
  passcode text not null,
  constraint single_row check (id = 1)
);

create table if not exists clients (
  id text primary key,
  nome text not null,
  stage text not null default 'potenciais',
  pet text,
  contato text,
  data1 date,
  data_compra date,
  obs text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clients_stage_idx on clients (stage);

create table if not exists payments (
  id text primary key,
  data date not null,
  valor numeric(12,2) not null,
  descricao text not null,
  categoria text,
  investido_por text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists payments_data_idx on payments (data);

create table if not exists withdrawals (
  id text primary key,
  data date not null,
  valor numeric(12,2) not null,
  descricao text,
  created_at timestamptz not null default now()
);

create index if not exists withdrawals_data_idx on withdrawals (data);

-- RLS: este projeto usa uma senha de equipe compartilhada (checada no
-- próprio app), não login individual do Supabase Auth. Por isso as
-- policies abaixo liberam acesso para a chave "anon" (a mesma chave
-- pública embutida no HTML). Ou seja: qualquer pessoa que tenha essa
-- chave (visível no código-fonte da página, mesmo com repo privado,
-- assim que a página for publicada) consegue ler e escrever nas
-- tabelas abaixo, independente da tela de senha do app.
--
-- Isso é aceitável para uma ferramenta interna simples, mas se os dados
-- dos clientes (nome, contato) forem sensíveis, o ideal é migrar para
-- Supabase Auth (login por e-mail) e trocar estas policies por
-- "auth.role() = 'authenticated'".

alter table crm_config enable row level security;
alter table clients enable row level security;
alter table payments enable row level security;
alter table withdrawals enable row level security;

create policy "anon full access - crm_config" on crm_config
  for all using (true) with check (true);

create policy "anon full access - clients" on clients
  for all using (true) with check (true);

create policy "anon full access - payments" on payments
  for all using (true) with check (true);

create policy "anon full access - withdrawals" on withdrawals
  for all using (true) with check (true);
