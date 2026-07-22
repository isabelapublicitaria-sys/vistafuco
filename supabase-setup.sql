-- Vista Fuço CRM — setup do banco no Supabase
-- Rode isso uma vez em: Supabase Dashboard > SQL Editor > New query > Run
--
-- MODELO DE SEGURANÇA
-- Login individual por e-mail via Supabase Auth. Cada pessoa da equipe
-- precisa ter um usuário criado em Authentication > Users no painel do
-- Supabase (Add user > defina e-mail e senha). O app não tem tela de
-- cadastro — as contas são criadas só por quem administra o projeto.
--
-- As tabelas só podem ser lidas/escritas por quem estiver autenticado
-- (login válido). A chave "anon" sozinha (sem login) não acessa nada.

-- Se você rodou uma versão antiga deste script (esquema de senha
-- compartilhada), isso remove tudo que não é mais usado.
drop table if exists crm_config cascade;
drop function if exists crm_is_configured();
drop function if exists crm_setup_passcode(text);
drop function if exists crm_check_passcode(text);
drop function if exists crm_assert_passcode(text);
drop function if exists crm_list_clients(text);
drop function if exists crm_upsert_client(text, text, text, text, text, text, date, date, text);
drop function if exists crm_update_client_stage(text, text, text);
drop function if exists crm_delete_client(text, text);
drop function if exists crm_list_payments(text);
drop function if exists crm_upsert_payment(text, text, date, numeric, text, text, text);
drop function if exists crm_delete_payment(text, text);
drop function if exists crm_list_withdrawals(text);
drop function if exists crm_upsert_withdrawal(text, text, date, numeric, text);
drop function if exists crm_delete_withdrawal(text, text);

create table if not exists clients (
  id text primary key,
  nome text not null,
  stage text not null default 'potenciais',
  pet text,
  contato text,
  origem text,
  data1 date,
  data_compra date,
  obs text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Se a tabela já existia (versão anterior sem "Origem"), adiciona a coluna.
alter table clients add column if not exists origem text;

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
  recebido_por text,
  created_at timestamptz not null default now()
);

create index if not exists withdrawals_data_idx on withdrawals (data);

-- Se a tabela já existia (versão anterior sem "Conta"), adiciona a coluna.
alter table withdrawals add column if not exists recebido_por text;

create table if not exists sales (
  id text primary key,
  data date not null,
  quantidade integer not null default 1,
  lucro numeric(12,2) not null,
  created_at timestamptz not null default now()
);

create index if not exists sales_data_idx on sales (data);

create table if not exists transfers (
  id text primary key,
  data date not null,
  valor numeric(12,2) not null,
  enviado_para text not null,
  descricao text,
  tipo text not null default 'enviado',
  created_at timestamptz not null default now()
);

alter table transfers add column if not exists tipo text not null default 'enviado';

create index if not exists transfers_data_idx on transfers (data);

-- Linha por mês da aba "Visão geral" — tudo aqui é ajustado manualmente
-- por Isabela/Mariane (o app só sugere um valor inicial), porque o
-- histórico de repasses mistura acerto de gastos+saque com outras coisas
-- (repasse de lucro, etc.) que uma fórmula fixa não consegue separar com
-- certeza.
create table if not exists monthly_balances (
  id text primary key,
  saldo_isabela numeric(12,2) not null default 0,
  saldo_mariane numeric(12,2) not null default 0,
  deveria_receber_isabela numeric(12,2) not null default 0,
  deveria_receber_mariane numeric(12,2) not null default 0,
  saldo_mes_isabela numeric(12,2) not null default 0,
  saldo_mes_mariane numeric(12,2) not null default 0,
  pix_enviado boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table monthly_balances add column if not exists deveria_receber_isabela numeric(12,2) not null default 0;
alter table monthly_balances add column if not exists deveria_receber_mariane numeric(12,2) not null default 0;
alter table monthly_balances add column if not exists saldo_mes_isabela numeric(12,2) not null default 0;
alter table monthly_balances add column if not exists saldo_mes_mariane numeric(12,2) not null default 0;
alter table monthly_balances add column if not exists pix_enviado boolean not null default false;

create table if not exists marketing (
  id integer primary key default 1,
  persona text,
  publico_alvo text,
  tom_de_voz text,
  logo_url text,
  cores jsonb not null default '[]'::jsonb,
  plano text,
  updated_at timestamptz not null default now(),
  constraint single_row check (id = 1)
);

alter table clients enable row level security;
alter table payments enable row level security;
alter table withdrawals enable row level security;
alter table sales enable row level security;
alter table transfers enable row level security;
alter table monthly_balances enable row level security;
alter table marketing enable row level security;

drop policy if exists "authenticated full access - clients" on clients;
drop policy if exists "authenticated full access - payments" on payments;
drop policy if exists "authenticated full access - withdrawals" on withdrawals;
drop policy if exists "authenticated full access - sales" on sales;
drop policy if exists "authenticated full access - transfers" on transfers;
drop policy if exists "authenticated full access - monthly_balances" on monthly_balances;

create policy "authenticated full access - clients" on clients
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access - payments" on payments
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access - withdrawals" on withdrawals
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access - sales" on sales
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access - transfers" on transfers
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "authenticated full access - monthly_balances" on monthly_balances
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access - marketing" on marketing;
create policy "authenticated full access - marketing" on marketing
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant select, insert, update, delete on clients, payments, withdrawals, sales, transfers, monthly_balances, marketing to authenticated;
revoke all on clients, payments, withdrawals, sales, transfers, monthly_balances, marketing from anon;
