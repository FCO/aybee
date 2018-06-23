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

