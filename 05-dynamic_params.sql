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
        jsonb_object_agg(var.name, vv.value)
    from
        aybee_dashboard.variable_variant as vv,
        aybee_dashboard.variable var
    where
        vv.variant_id = variant.id
        and vv.variable_id = var.id
$$ language sql stable;
