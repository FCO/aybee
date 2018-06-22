create  schema if not exists aybee;
create  schema if not exists aybee_private;
create  schema if not exists aybee_dashboard;

create  extension if not exists "uuid-ossp";
create  extension if not exists "pgcrypto";
create  extension if not exists "btree_gist";
alter   default privileges revoke execute on functions from public;

create  role aybee_postgraphile login password 'xyz';
create  role aybee_anonymous;
create  role aybee_dashboard_loggedin;
grant   aybee_anonymous             to aybee_postgraphile;
grant   aybee_dashboard_loggedin    to aybee_postgraphile;

-----------------------------------------------------------------------------------------------------------

drop type if exists aybee_dashboard.jwt_token cascade;
drop type if exists aybee_dashboard.authenticate_select_response cascade;

create type aybee_dashboard.jwt_token as (
  role              text,
  person_id         uuid,
  organization_id   uuid,
  admin             integer
);

create type aybee_dashboard.authenticate_select_response as (
  role text,
  person_id uuid,
  organization_id uuid,
  password_hash text,
  admin integer
);

-----------------------------------------------------------------------------------------------------------

drop table if exists aybee_dashboard.organization   cascade;
drop table if exists aybee_dashboard.person         cascade;
drop table if exists aybee_private.account          cascade;
drop table if exists aybee_dashboard.platform       cascade;
drop table if exists aybee_dashboard.track          cascade;
drop table if exists aybee_dashboard.experiment     cascade;
drop table if exists aybee_dashboard.variant        cascade;
drop table if exists aybee_dashboard.variant_track  cascade;

create table aybee_dashboard.organization (
    id      uuid    not null    primary key default uuid_generate_v1mc(),
    name    varchar not null    unique
);
comment on table aybee_dashboard.organization is 'A organization';

create table aybee_dashboard.person (
    id              uuid    not null primary key default uuid_generate_v1mc(),
    organization_id uuid    not null references aybee_dashboard.organization(id),
    name            varchar,
    admin           bool    default 'f'
);
comment on table aybee_dashboard.person is 'A dashboard user';

create table aybee_private.account (
    person_id        uuid not null primary key references aybee_dashboard.person(id),
    email            text not null unique check (email ~* '^.+@.+\..+$'),
    password_hash    text not null
);

create table aybee_dashboard.platform (
    id               uuid not null primary key default uuid_generate_v1mc(),
    organization_id  uuid not null references aybee_dashboard.organization(id),
    name             text not null,
    unique (organization_id, name)
);

create table aybee_dashboard.track (
    id               uuid not null primary key default uuid_generate_v1mc(),
    organization_id  uuid not null references aybee_dashboard.organization(id),
    platform_id      uuid not null references aybee_dashboard.platform(id),
    name             text not null,
    unique (organization_id, platform_id, name)
);

create table aybee_dashboard.experiment (
    id               uuid not null primary key default uuid_generate_v1mc(),
    organization_id  uuid not null references aybee_dashboard.organization(id),
    track_id         uuid not null references aybee_dashboard.track(id),
    name             text not null,
    unique (track_id, name)
);

create table aybee_dashboard.variant (
    id               uuid       not null primary key default uuid_generate_v1mc(),
    organization_id  uuid not null references aybee_dashboard.organization(id),
    experiment_id    uuid       not null references aybee_dashboard.experiment(id),
    name             text       not null,
    percent          numeric    not null,
    unique (experiment_id, name),
    check  (percent <= 1)
);

create table aybee_dashboard.variant_track (
    id               uuid       not null primary key default uuid_generate_v1mc(),
    organization_id  uuid not null references aybee_dashboard.organization(id),
    track_id         uuid       not null references aybee_dashboard.track(id),
    variant_id       uuid       not null references aybee_dashboard.variant(id),
    percent_range    numrange   not null,
    exclude using gist (track_id with =, percent_range with &&)
);

----------------------------------------------------------------------------------------------------------

create or replace function aybee_dashboard.track_percentage_used(
    track aybee_dashboard.track
) returns numeric as $$
    select coalesce(sum(coalesce(upper(percent_range) - lower(percent_range), 0)), 0)
    from aybee_dashboard.variant_track
    where track_id = track.id;
$$ language sql stable;

create or replace function aybee_dashboard.track_percentage_free(
    track aybee_dashboard.track
) returns numeric as $$
    select 1 - aybee_dashboard.track_percentage_used(track);
$$ language sql stable;

create or replace function aybee_dashboard.track_free_ranges(
    track aybee_dashboard.track
) returns setof numrange as $$
    with
    ranges as (
        select
            '(,0]'::numrange as range
    union
        select
            percent_range as range
        from
            aybee_dashboard.variant_track
        where
            track_id = track.id
    union
        select
            '(1,]'::numrange as range
        order by
            1
    ),
    r as (
        select
            range,
            lead(range) over() as lrange
        from
            ranges
    )
    select
        numrange(upper(range), lower(lrange), '(]')
    from
        r
    where
        not range -|- lrange
    ;
$$ language sql stable;

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
$$ language plpgsql strict;

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

create or replace function aybee_dashboard.authenticate(
  email text,
  password text
) returns aybee_dashboard.jwt_token as $$
declare
  acc aybee_dashboard.authenticate_select_response;
begin
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

create or replace function aybee_dashboard.logged_organization() returns aybee_dashboard.organization as $$
  select *
  from aybee_dashboard.organization
  where id = current_setting('jwt.claims.organization_id')::uuid
$$ language sql stable;

comment on function aybee_dashboard.logged_organization() is 'Gets the organization who was identified by our JWT.';

create or replace function aybee_dashboard.register_platform(
  name      text
) returns aybee_dashboard.platform as $$
declare
  organization_id   uuid;
  platform          aybee_dashboard.platform;
begin
  select current_setting('jwt.claims.organization_id')::uuid into organization_id;
  insert into aybee_dashboard.platform(name, organization_id)
    values(name, organization_id) returning * into platform;
  return platform;
end;
$$ language plpgsql strict;

comment on function aybee_dashboard.register_person(text, text, text, bool) is 'Registers a single user and creates an account in our forum.';

create or replace function aybee_dashboard.register_track(
  platform  text,
  name      text
) returns aybee_dashboard.track as $$
declare
  organization_id   uuid;
  platform_id       uuid;
  track             aybee_dashboard.track;
begin
  select current_setting('jwt.claims.organization_id')::uuid into organization_id;
  select id from aybee_dashboard.platform p into platform_id where p.name = platform;
  insert into aybee_dashboard.track(name, platform_id, organization_id)
    values(name, platform_id, organization_id) returning * into track;
  return track;
end;
$$ language plpgsql strict;

comment on function aybee_dashboard.register_person(text, text, text, bool) is 'Registers a single user and creates an account in our forum.';



-----------------------------------------------------------------------------------------------------------------------


grant usage on schema aybee_dashboard                               to aybee_anonymous, aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.authenticate(text, text)  to aybee_anonymous, aybee_dashboard_loggedin;

grant select, update, insert, delete on table aybee_dashboard.person        to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.organization  to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.platform      to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.track         to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.experiment    to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variant       to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variant_track to aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.logged_user()             to aybee_anonymous, aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.logged_organization()     to aybee_anonymous, aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.add_variation_to_track(aybee_dashboard.variant)   to aybee_anonymous;
grant execute on function aybee_dashboard.register_organization(text, text, text, text)     to aybee_anonymous;
grant execute on function aybee_dashboard._register_person(uuid, text, text, text, bool)    to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_person(text, text, text, bool)           to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_platform(text)                           to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_track(text, text)                        to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_percentage_used(aybee_dashboard.track)      to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_percentage_free(aybee_dashboard.track)      to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_free_ranges(aybee_dashboard.track)          to aybee_dashboard_loggedin;


----------------------------------------------------------------------------------------------------------------------


alter table aybee_dashboard.person          enable row level security;
alter table aybee_dashboard.organization    enable row level security;

create policy select_person         on aybee_dashboard.person           for select  using (
    id = current_setting('jwt.claims.person_id')::uuid
    or (
        current_setting('jwt.claims.admin')::integer = 1
        and organization_id = current_setting('jwt.claims.organization_id')::uuid
    )
);
create policy select_organization   on aybee_dashboard.organization     for select  using (
    id = current_setting('jwt.claims.organization_id')::uuid
);
create policy update_organization   on aybee_dashboard.organization     for update  using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);
create policy delete_organization   on aybee_dashboard.organization     for delete  using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);
create policy select_platform       on aybee_dashboard.platform         for select  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy select_track          on aybee_dashboard.track            for select  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy select_experiment     on aybee_dashboard.experiment       for select  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy select_variant        on aybee_dashboard.variant          for select  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy select_variant_track  on aybee_dashboard.variant_track    for select  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

create policy insert_track          on aybee_dashboard.track            for insert  with check (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy insert_experiment     on aybee_dashboard.experiment       for insert  with check (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy insert_variant        on aybee_dashboard.variant          for insert  with check (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy insert_variant_track  on aybee_dashboard.variant_track    for insert  with check (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

create policy update_track          on aybee_dashboard.track            for update  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy update_experiment     on aybee_dashboard.experiment       for update  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy update_variant        on aybee_dashboard.variant          for update  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy update_variant_track  on aybee_dashboard.variant_track    for update  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

create policy delete_track          on aybee_dashboard.track            for delete  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy delete_experiment     on aybee_dashboard.experiment       for delete  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy delete_variant        on aybee_dashboard.variant          for delete  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
create policy delete_variant_track  on aybee_dashboard.variant_track    for delete  using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);


-------------------------------------------------------------------------------------------------------------------


create or replace function aybee_dashboard.add_variation_to_track() returns trigger as $$
declare
    experiment aybee_dashboard.experiment;
    track aybee_dashboard.track;
    reamain_size numeric;
    range numrange;
begin
    select
        t.*
    into
        track
    from
        aybee_dashboard.track as t,
        aybee_dashboard.experiment as e
    where
        t.id = e.track_id
        and new.experiment_id = e.id;

    if aybee_dashboard.track_percentage_free(track) < new.percent then
        RAISE EXCEPTION 'Could not add variant % of size % on track %', new.name, new.percent, track.name
            USING HINT = 'Is this track full?';
    end if;
    reamain_size := new.percent;
    for range in select * from aybee_dashboard.track_free_ranges(track) loop
        insert into aybee_dashboard.variant_track(track_id, variant_id, organization_id, percent_range)
        values(track.id, new.id, new.organization_id, numrange(lower(range), lower(range) + reamain_size, '(]'));
        reamain_size := reamain_size - (upper(range) - lower(range));
        if reamain_size <= 0 then
            exit;
        end if;
    end loop;
    if reamain_size > 0 then
        RAISE EXCEPTION 'Could not add variant % on track %', new.name, track.name
            USING HINT = 'Something was wrong';
    end if;
    return new;
end;
$$ language plpgsql;

drop TRIGGER if exists insert_variant on aybee_dashboard.variant;

CREATE TRIGGER insert_variant
    AFTER INSERT ON aybee_dashboard.variant
    FOR EACH ROW
    EXECUTE PROCEDURE aybee_dashboard.add_variation_to_track();


-------------------------------------------------------------------------------------------------------------------


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

insert into aybee_private.account(person_id, email, password_hash)
    values('298990a4-6f55-11e8-a172-db9b0a334b77', 'a@b.com', crypt('senha', gen_salt('bf')));

insert into aybee_dashboard.platform( id, organization_id, name )
    values('979fc2bc-6f54-11e8-a172-7fb168c1de7f', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', 'iOS');
insert into aybee_dashboard.track( id, organization_id, platform_id, name )
    values('979fc2bc-6f54-11e8-a172-7fb168c1de7f', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', 'test 001');
