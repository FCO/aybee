create or replace function aybee_dashboard.add_percentage_of_variant_to_track(
    variant         aybee_dashboard.variant,
    track           aybee_dashboard.track,
    add_percentage  numeric
) returns void as $$
declare
    experiment aybee_dashboard.experiment;
    reamain_size numeric;
    range numrange;
begin
    if aybee_dashboard.track_percentage_free(track) < add_percentage then
        RAISE EXCEPTION 'Could not add variant % of size % on track %', variant.name, variant.percent, track.name
            USING HINT = 'Is this track full?';
    end if;
    reamain_size := add_percentage;
    for range in select * from aybee_dashboard.track_free_ranges(track) loop
        insert into aybee_dashboard.variant_track(track_id, variant_id, organization_id, percent_range)
        values(track.id, variant.id, variant.organization_id, numrange(lower(range), lower(range) + reamain_size, '[)'));
        reamain_size := reamain_size - (upper(range) - lower(range));
        if reamain_size <= 0 then
            exit;
        end if;
    end loop;
    if reamain_size > 0 then
        RAISE EXCEPTION 'Could not add variant % on track %', variant.name, track.name
            USING HINT = 'Something was wrong';
    end if;
end;
$$ language plpgsql;

create or replace function aybee_dashboard.add_variant_to_track() returns trigger as $$
declare
    track aybee_dashboard.track;
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

        PERFORM aybee_dashboard.add_percentage_of_variant_to_track(new, track, new.percent);
    return new;
end;
$$ language plpgsql;

drop TRIGGER if exists insert_variant on aybee_dashboard.variant;

CREATE TRIGGER insert_variant
    AFTER INSERT ON aybee_dashboard.variant
    FOR EACH ROW
    EXECUTE PROCEDURE aybee_dashboard.add_variant_to_track();
