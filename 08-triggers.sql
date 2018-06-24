create or replace function aybee_dashboard.add_variant_to_track() returns trigger as $$
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
    EXECUTE PROCEDURE aybee_dashboard.add_variant_to_track();
