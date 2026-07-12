-- Vista Fuço CRM — setup do banco no Supabase
-- Rode isso uma vez em: Supabase Dashboard > SQL Editor > New query > Run
--
-- MODELO DE SEGURANÇA
-- A chave "anon" usada pelo app é pública por natureza (fica visível no
-- código da página, mesmo com repositório privado). Por isso as tabelas
-- abaixo NÃO são acessíveis diretamente por essa chave — todo acesso
-- (ler, criar, editar, excluir) passa por funções (RPC) que exigem a
-- senha da equipe como parâmetro e a conferem no servidor antes de fazer
-- qualquer coisa. Assim, mesmo que a chave "anon" vaze (repo público,
-- alguém inspecionando a página, etc.), ninguém acessa os dados sem
-- saber a senha.
--
-- Isso ainda é uma senha única compartilhada pela equipe (não é login
-- individual). Se um dia precisar de contas separadas por pessoa, o
-- caminho é migrar para Supabase Auth de verdade.

create extension if not exists pgcrypto;

-- Se você já rodou uma versão antiga deste script (com policy "anon full
-- access"), isto substitui a config antiga por uma versão com hash.
drop table if exists crm_config cascade;

create table crm_config (
  id integer primary key default 1,
  passcode_hash text not null,
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

-- RLS ligado, mas sem nenhuma policy para anon/authenticated: acesso
-- direto às tabelas fica bloqueado por padrão. Só as funções abaixo
-- (rodando como "security definer") conseguem ler/escrever nelas.
alter table crm_config enable row level security;
alter table clients enable row level security;
alter table payments enable row level security;
alter table withdrawals enable row level security;

revoke all on crm_config, clients, payments, withdrawals from anon, authenticated;

-- ================= Funções auxiliares de senha =================

create or replace function crm_is_configured()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(select 1 from crm_config where id = 1);
$$;

create or replace function crm_setup_passcode(new_passcode text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists(select 1 from crm_config where id = 1) then
    return false;
  end if;
  if new_passcode is null or length(new_passcode) < 4 then
    raise exception 'Senha muito curta';
  end if;
  insert into crm_config (id, passcode_hash) values (1, crypt(new_passcode, gen_salt('bf')));
  return true;
end;
$$;

create or replace function crm_check_passcode(passcode text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select passcode_hash = crypt(passcode, passcode_hash) from crm_config where id = 1),
    false
  );
$$;

-- Assert interna: usada no início de toda função que mexe em dados.
create or replace function crm_assert_passcode(passcode text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not crm_check_passcode(passcode) then
    raise exception 'Senha incorreta';
  end if;
end;
$$;

-- ================= Clients =================

create or replace function crm_list_clients(passcode text)
returns setof clients
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  return query select * from clients order by updated_at desc;
end;
$$;

create or replace function crm_upsert_client(
  passcode text, p_id text, p_nome text, p_stage text, p_pet text,
  p_contato text, p_data1 date, p_data_compra date, p_obs text
)
returns clients
language plpgsql
security definer
set search_path = public
as $$
declare
  result clients;
begin
  perform crm_assert_passcode(passcode);
  insert into clients (id, nome, stage, pet, contato, data1, data_compra, obs, updated_at)
  values (p_id, p_nome, p_stage, p_pet, p_contato, p_data1, p_data_compra, p_obs, now())
  on conflict (id) do update set
    nome = excluded.nome, stage = excluded.stage, pet = excluded.pet,
    contato = excluded.contato, data1 = excluded.data1, data_compra = excluded.data_compra,
    obs = excluded.obs, updated_at = now()
  returning * into result;
  return result;
end;
$$;

create or replace function crm_update_client_stage(passcode text, p_id text, p_stage text)
returns clients
language plpgsql
security definer
set search_path = public
as $$
declare
  result clients;
begin
  perform crm_assert_passcode(passcode);
  update clients set stage = p_stage, updated_at = now() where id = p_id returning * into result;
  return result;
end;
$$;

create or replace function crm_delete_client(passcode text, p_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  delete from clients where id = p_id;
end;
$$;

-- ================= Payments =================

create or replace function crm_list_payments(passcode text)
returns setof payments
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  return query select * from payments order by data desc;
end;
$$;

create or replace function crm_upsert_payment(
  passcode text, p_id text, p_data date, p_valor numeric, p_descricao text,
  p_categoria text, p_investido_por text
)
returns payments
language plpgsql
security definer
set search_path = public
as $$
declare
  result payments;
begin
  perform crm_assert_passcode(passcode);
  insert into payments (id, data, valor, descricao, categoria, investido_por, updated_at)
  values (p_id, p_data, p_valor, p_descricao, p_categoria, p_investido_por, now())
  on conflict (id) do update set
    data = excluded.data, valor = excluded.valor, descricao = excluded.descricao,
    categoria = excluded.categoria, investido_por = excluded.investido_por, updated_at = now()
  returning * into result;
  return result;
end;
$$;

create or replace function crm_delete_payment(passcode text, p_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  delete from payments where id = p_id;
end;
$$;

-- ================= Withdrawals =================

create or replace function crm_list_withdrawals(passcode text)
returns setof withdrawals
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  return query select * from withdrawals order by data desc;
end;
$$;

create or replace function crm_upsert_withdrawal(
  passcode text, p_id text, p_data date, p_valor numeric, p_descricao text
)
returns withdrawals
language plpgsql
security definer
set search_path = public
as $$
declare
  result withdrawals;
begin
  perform crm_assert_passcode(passcode);
  insert into withdrawals (id, data, valor, descricao)
  values (p_id, p_data, p_valor, p_descricao)
  on conflict (id) do update set
    data = excluded.data, valor = excluded.valor, descricao = excluded.descricao
  returning * into result;
  return result;
end;
$$;

create or replace function crm_delete_withdrawal(passcode text, p_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform crm_assert_passcode(passcode);
  delete from withdrawals where id = p_id;
end;
$$;

-- Libera só a execução das funções para a chave anon (nunca as tabelas).
grant execute on function
  crm_is_configured(), crm_setup_passcode(text), crm_check_passcode(text),
  crm_list_clients(text), crm_upsert_client(text, text, text, text, text, text, date, date, text),
  crm_update_client_stage(text, text, text), crm_delete_client(text, text),
  crm_list_payments(text), crm_upsert_payment(text, text, date, numeric, text, text, text),
  crm_delete_payment(text, text),
  crm_list_withdrawals(text), crm_upsert_withdrawal(text, text, date, numeric, text),
  crm_delete_withdrawal(text, text)
to anon, authenticated;
