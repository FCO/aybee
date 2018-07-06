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

create type aybee_dashboard.id_percent_range as (
    id              uuid,
    percent_range   numrange
);

create type aybee_dashboard.config as (
    track       text,
    salt        uuid,
    identifier  text,
    experiment  text,
    variant     text,
    percent     numeric,
    variables   jsonb,
    ranges      numrange[]
);
