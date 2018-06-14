create schema if not exists aybee;
create schema if not exists aybee_private;
create schema if not exists aybee_dashboard;

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
alter default privileges revoke execute on functions from public;

create role aybee_postgraphile login password 'xyz';
create role aybee_anonymous;
create role aybee_dashboard_loggedin;
grant aybee_anonymous to aybee_postgraphile;
grant aybee_dashboard_loggedin to aybee_postgraphile;

drop type if exists aybee_dashboard.jwt_token cascade;
create type aybee_dashboard.jwt_token as (
  role text,
  person_id uuid,
  organization_id uuid,
  admin integer
);

drop table if exists aybee_dashboard.organization cascade;
create table aybee_dashboard.organization (
    id      uuid primary key default uuid_generate_v1mc(),
    name    varchar not null unique
);
comment on table aybee_dashboard.organization is 'A organization';

drop table if exists aybee_dashboard.person cascade;
create table aybee_dashboard.person (
    id              uuid primary key default uuid_generate_v1mc(),
    organization_id uuid not null references aybee_dashboard.organization(id),
    name            varchar,
    admin           bool default 'f'
);
comment on table aybee_dashboard.person is 'A dashboard user';

drop table if exists aybee_private.account cascade;
create table aybee_private.account (
    person_id        uuid primary key references aybee_dashboard.person(id),
    email            text not null unique check (email ~* '^.+@.+\..+$'),
    password_hash    text not null
);

create or replace function aybee_dashboard.register_organization(
  name text,
  username text,
  email text,
  password text
) returns aybee_dashboard.organization as $$
declare
  organization aybee_dashboard.organization;
begin
  insert into aybee_dashboard.organization (name) values (name) returning * into organization;

  PERFORM aybee_dashboard._register_person(organization.id, username, email, password, 't');

  return organization;
end;
$$ language plpgsql strict security definer;

comment on function aybee_dashboard.register_organization(text, text, text, text) is 'Registers a organization and an admin user for it';


create or replace function aybee_dashboard.register_person(
  name text,
  email text,
  password text,
  admin bool default 'f'
) returns aybee_dashboard.person as $$
declare
  organization_id uuid;
  person aybee_dashboard.person;
begin
  select current_setting('jwt.claims.organization_id')::uuid into organization_id;
  return aybee_dashboard._register_person(organization_id, name, email, password, admin);
end;
$$ language plpgsql strict security definer;

comment on function aybee_dashboard.register_person(text, text, text, bool) is 'Registers a single user and creates an account in our forum.';

create or replace function aybee_dashboard._register_person(
  organization_id uuid,
  name text,
  email text,
  password text,
  admin bool default 'f'
) returns aybee_dashboard.person as $$
declare
  person aybee_dashboard.person;
begin
  insert into aybee_dashboard.person (organization_id, name, admin) values
    (organization_id, name, admin)
    returning * into person;

  insert into aybee_private.account (person_id, email, password_hash) values
    (person.id, email, crypt(password, gen_salt('bf')));

  return person;
end;
$$ language plpgsql strict security definer;

comment on function aybee_dashboard._register_person(uuid, text, text, text, bool) is 'Registers a single user and creates an account in our forum.';

drop type if exists aybee_dashboard.authenticate_select_response cascade;
create type aybee_dashboard.authenticate_select_response as (
  role text,
  person_id uuid,
  organization_id uuid,
  password_hash text,
  admin integer
);


create or replace function aybee_dashboard.authenticate(
  email text,
  password text
) returns aybee_dashboard.jwt_token as $$
declare
  acc aybee_dashboard.authenticate_select_response;
begin
  --raise EXCEPTION 'email => %; password => %', email, password;
  select 'aybee_dashboard_loggedin' as role, a.person_id, b.organization_id, a.password_hash, b.admin::integer into acc
  from aybee_private.account as a, aybee_dashboard.person as b
  where a.person_id = b.id AND a.email = $1;

  if acc.password_hash = crypt(password, acc.password_hash) then
    return (acc.role, acc.person_id, acc.organization_id, acc.admin::integer)::aybee_dashboard.jwt_token;
  else
    return null;
  end if;
end;
$$ language plpgsql strict security definer;

comment on function aybee_dashboard.authenticate(text, text) is 'Creates a JWT token that will securely identify a person and give them certain permissions.';

create or replace function aybee_dashboard.logged_user() returns aybee_dashboard.person as $$
  select *
  from aybee_dashboard.person
  where id = current_setting('jwt.claims.person_id')::uuid
$$ language sql stable;

comment on function aybee_dashboard.logged_user() is 'Gets the person who was identified by our JWT.';



grant usage on schema aybee_dashboard to aybee_anonymous, aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.authenticate(text, text) to aybee_anonymous, aybee_dashboard_loggedin;

grant select, update, delete on table aybee_dashboard.person to aybee_dashboard_loggedin;
grant select, update, delete on table aybee_dashboard.organization to aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.logged_user() to aybee_anonymous, aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.register_organization(text, text, text, text) to aybee_anonymous;
grant execute on function aybee_dashboard._register_person(uuid, text, text, text, bool) to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_person(text, text, text, bool) to aybee_dashboard_loggedin;





alter table aybee_dashboard.person enable row level security;
alter table aybee_dashboard.organization enable row level security;


create policy select_person on aybee_dashboard.person for select using (
    id = current_setting('jwt.claims.person_id')::uuid
    or (
        current_setting('jwt.claims.admin')::integer = 1
        and organization_id = current_setting('jwt.claims.organization_id')::uuid
    )
);
create policy select_organization on aybee_dashboard.organization for select using (
    id = current_setting('jwt.claims.organization_id')::uuid
);
create policy update_organization on aybee_dashboard.organization for update using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);
create policy delete_organization on aybee_dashboard.organization for delete using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);


insert into aybee_dashboard.organization( id, name ) values ('979fc2bc-6f54-11e8-a172-7fb168c1de7f', 'aybee');
insert into aybee_dashboard.person( id, organization_id, name ) values (
    '298990a4-6f55-11e8-a172-db9b0a334b77',
    '979fc2bc-6f54-11e8-a172-7fb168c1de7f',
    'aybee'
);

insert into aybee_dashboard.organization( id, name ) values ('979fc2bc-6f54-11e8-a172-222222222222', 'aybee2');
insert into aybee_dashboard.person( id, organization_id, name ) values (
    '298990a4-6f55-11e8-a172-222222222222',
    '979fc2bc-6f54-11e8-a172-222222222222',
    'aybee2'
);

