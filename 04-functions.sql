create or replace function aybee_private.register_organization_and_set_claims(
  name text,
  username text,
  email text,
  password text
) returns void as $$
declare
  org_id uuid;
begin
    select id into org_id from aybee_dashboard.register_organization(name, username, email, password);
    set local jwt.claims.organization_id to org_id;
end;
$$ language plpgsql;

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

create or replace function aybee_dashboard.register_experiment(
  name      text
) returns aybee_dashboard.experiment as $$
declare
  organization_id   uuid;
  experiment        aybee_dashboard.experiment;
begin
  select current_setting('jwt.claims.organization_id')::uuid into organization_id;
  insert into aybee_dashboard.experiment(name, organization_id)
    values(name, organization_id) returning * into experiment;
  return experiment;
end;
$$ language plpgsql strict;

--create or replace function aybee_dashboard.register_experiment(
--  name          text,
--  track_name    text
--) returns aybee_dashboard.experiment as $$
--declare
--  organization_id   uuid;
--  track_id          uuid;
--  experiment        aybee_dashboard.experiment;
--begin
--  select current_setting('jwt.claims.organization_id')::uuid into organization_id;
--  select id into track_id from track where name = track_name;
--  insert into aybee_dashboard.experiment(name, organization_id, track_id)
--    values(name, organization_id, track_id) returning * into experiment;
--  return experiment;
--end;
--$$ language plpgsql strict;

--comment on function aybee_dashboard.register_person(text, text, text, bool) is 'Registers a single user and creates an account in our forum.';

create or replace function aybee_dashboard.copy_track(
  track      aybee_dashboard.track
) returns aybee_dashboard.track as $$
  insert into aybee_dashboard.track(name, organization_id, platform_id, salt, copy_of)
    values(track.name || ' (copy)', track.organization_id, track.platform_id, track.salt, track.id) returning *;
$$ language sql strict;


create or replace function aybee_dashboard.segregate_experiment(
  ex aybee_dashboard.experiment
) returns aybee_dashboard.experiment as $$
declare
    old_track aybee_dashboard.track;
    new_track aybee_dashboard.track;
begin
  update aybee_dashboard.experiment set segregating = 't' where id = ex.id;
  select * into old_track from aybee_dashboard.track where id = ex.track_id;
  select * into new_track FROM aybee_dashboard.copy_track(old_track);
  update aybee_dashboard.variant_track set track_id = new_track.id where variant_id in (
    select id from aybee_dashboard.variant where experiment_id = ex.id
  );
  update aybee_dashboard.experiment set track_id = new_track.id, segregating = 'f' where id = ex.id;
  return ex;
end;
$$ language plpgsql strict;

