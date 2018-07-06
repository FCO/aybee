alter table aybee_dashboard.person              enable row level security;
alter table aybee_dashboard.organization        enable row level security;
alter table aybee_dashboard.platform            enable row level security;
alter table aybee_dashboard.track               enable row level security;
alter table aybee_dashboard.experiment          enable row level security;
alter table aybee_dashboard.variant             enable row level security;
alter table aybee_dashboard.variant_track       enable row level security;
alter table aybee_dashboard.variable            enable row level security;
alter table aybee_dashboard.variable_variant    enable row level security;

drop policy IF EXISTS select_person on aybee_dashboard.person;
create policy select_person         on aybee_dashboard.person           for select  using (
    id = current_setting('jwt.claims.person_id')::uuid
    or (
        current_setting('jwt.claims.admin')::integer = 1
        and organization_id = current_setting('jwt.claims.organization_id')::uuid
    )
);

drop policy IF EXISTS select_organization on aybee_dashboard.organization;
create policy select_organization   on aybee_dashboard.organization     for select  using (
    id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS update_organization on aybee_dashboard.organization;
create policy update_organization   on aybee_dashboard.organization     for update  using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);

drop policy IF EXISTS delete_organization on aybee_dashboard.organization;
create policy delete_organization   on aybee_dashboard.organization     for delete  using (
    id = current_setting('jwt.claims.organization_id')::uuid
    and current_setting('jwt.claims.admin')::integer = 1
);

drop policy IF EXISTS select_platform on aybee_dashboard.platform;
create policy select_platform       on aybee_dashboard.platform using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_track on aybee_dashboard.track;
create policy select_track          on aybee_dashboard.track using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_identifier on aybee_dashboard.identifier;
create policy select_identifier          on aybee_dashboard.identifier using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_experiment on aybee_dashboard.experiment;
create policy select_experiment     on aybee_dashboard.experiment using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_variant on aybee_dashboard.variant;
create policy select_variant        on aybee_dashboard.variant using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_variable on aybee_dashboard.variable;
create policy select_variable        on aybee_dashboard.variable using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_variable_variant on aybee_dashboard.variable_variant;
create policy select_variable_variant        on aybee_dashboard.variable_variant using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);

drop policy IF EXISTS select_variant_track on aybee_dashboard.variant_track;
create policy select_variant_track  on aybee_dashboard.variant_track using (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
) with check (
    organization_id = current_setting('jwt.claims.organization_id')::uuid
);
