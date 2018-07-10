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
        numrange(upper(range), lower(lrange), '[)')
    from
        r
    where
        not range -|- lrange
        and not isempty(numrange(upper(range), lower(lrange), '[)'))
    ;
$$ language sql stable;

create or replace function aybee_dashboard.variant_variables(
    variant aybee_dashboard.variant
) returns jsonb as $$
    select
        coalesce(jsonb_object_agg(var.name, vv.value), '{}'::jsonb)
    from
        aybee_dashboard.variable_variant as vv,
        aybee_dashboard.variable var
    where
        vv.variant_id = variant.id
        and vv.variable_id = var.id
$$ language sql stable;

create or replace function aybee_dashboard.variant_ranges(
    variant aybee_dashboard.variant
) returns setof numrange as $$
    select
        vt.percent_range
    from
        aybee_dashboard.variant_track as vt
    where
        vt.variant_id = variant.id
$$ language sql stable;

create or replace function aybee_dashboard.get_config(
    organization uuid,
    platform     uuid
) returns setof aybee_dashboard.config as $$
    select
        t.name      as track,
        t.salt      as salt,
        i.name      as identifier,
        e.name      as experiment,
        v.name      as variant,
        v.percent   as percent,
        aybee_dashboard.variant_variables(v) as variables,
        ARRAY(select aybee_dashboard.variant_ranges(v)) as ranges
    from
        aybee_dashboard.track as t
        join aybee_dashboard.identifier as i on (i.id = t.identifier_id)
        join aybee_dashboard.variant_track as vt on (t.id = vt.track_id)
        join aybee_dashboard.variant as v on (vt.variant_id = v.id)
        join aybee_dashboard.experiment as e on (v.experiment_id = e.id)
    where
        t.organization_id = organization
        and t.platform_id = platform
    group by
        v.id, 1,2,3,4,5
    ;
$$ language sql stable strict security definer;

create or replace function aybee_dashboard.token_config(
    token aybee_dashboard.token
) returns setof aybee_dashboard.config as $$
    begin
    if token.active = 'f' then
        RAISE EXCEPTION 'Invalid token: %', token.id;
    end if;
    return query select
        *
    from
        aybee_dashboard.get_config(token.organization_id, token.platform_id)
    where
        token.active
    ;
    end;
$$ language plpgsql stable strict security definer;

create or replace function aybee_dashboard.token_metric_config(
    token aybee_dashboard.token
) returns aybee_dashboard.metric_config as $$
    declare
        conf    aybee_dashboard.metric_config;
    begin
        if token.active = 'f' then
            RAISE EXCEPTION 'Invalid token: %', token.id;
        end if;
        select
            *
        into
            conf
        from
            aybee_dashboard.metric_config
        where
            token.active
            AND token_id = token.id
        limit
            1
        ;
        return conf;
    end;
$$ language plpgsql stable strict security definer;

create or replace function aybee_dashboard.token_metric_type (
    token aybee_dashboard.token
) returns setof aybee_dashboard.metric_type as $$
    declare
        conf    aybee_dashboard.metric_type;
    begin
        if token.active = 'f' then
            RAISE EXCEPTION 'Invalid token: %', token.id;
        end if;
        return query select
            *
        from
            aybee_dashboard.metric_type
        where
            token.active
            AND organization_id = token.organization_id
        ;
    end;
$$ language plpgsql stable strict security definer;

