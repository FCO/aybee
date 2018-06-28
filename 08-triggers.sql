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
        if reamain_size <= upper(range) - lower(range) then
            insert into aybee_dashboard.variant_track(track_id, variant_id, organization_id, percent_range)
            values(track.id, variant.id, variant.organization_id, numrange(lower(range), lower(range) + reamain_size, '[)'));
            reamain_size := 0;
        else
            insert into aybee_dashboard.variant_track(track_id, variant_id, organization_id, percent_range)
            values(track.id, variant.id, variant.organization_id, numrange(lower(range), upper(range), '[)'));
            reamain_size := reamain_size - (upper(range) - lower(range));
        end if;
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

create or replace function aybee_dashboard.subtract_percentage_of_variant_to_track(
    variant             aybee_dashboard.variant,
    track               aybee_dashboard.track,
    subtract_percentage numeric
) returns void as $$
declare
    experiment aybee_dashboard.experiment;
    reamain_size numeric;
    range aybee_dashboard.id_percent_range;
begin
    if variant.percent < subtract_percentage then
        RAISE EXCEPTION 'Could not remove % from variant % on track % its size is %', subtract_percentage, variant.name, track.name, variant.percent
            USING HINT = 'Are you removing the right variant?';
    end if;
    reamain_size := subtract_percentage;
    for range in select id, percent_range from aybee_dashboard.variant_track where variant_id = variant.id order by 2 desc loop
        if upper(range.percent_range) - lower(range.percent_range) <= reamain_size then
            delete from aybee_dashboard.variant_track where id = range.id;
            reamain_size := reamain_size - (upper(range.percent_range) - lower(range.percent_range));
        else
            update aybee_dashboard.variant_track set percent_range = numrange(lower(range.percent_range), upper(range.percent_range) - reamain_size, '[)') where id = range.id;
            reamain_size := 0;
        end if;
        if reamain_size <= 0 then
            exit;
        end if;
    end loop;
    if reamain_size > 0 then
        RAISE EXCEPTION 'Could not remove variant % on track %', variant.name, track.name
            USING HINT = 'Something was wrong';
    end if;
end;
$$ language plpgsql;

create or replace function aybee_dashboard.create_variant_to_track() returns trigger as $$
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

create or replace function aybee_dashboard.increase_variant_to_track() returns trigger as $$
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

        PERFORM aybee_dashboard.add_percentage_of_variant_to_track(new, track, new.percent - old.percent);
    return new;
end;
$$ language plpgsql;

create or replace function aybee_dashboard.decrease_variant_to_track() returns trigger as $$
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

        PERFORM aybee_dashboard.subtract_percentage_of_variant_to_track(old, track, old.percent - new.percent);
    return new;
end;
$$ language plpgsql;

create or replace function aybee_dashboard.experiment_change_track() returns trigger as $$
declare
    variant     aybee_dashboard.variant;
    old_track   aybee_dashboard.track;
    new_track   aybee_dashboard.track;
begin
    RAISE NOTICE 'running trigger for experiment %', new.name;
    select * into old_track from aybee_dashboard.track where id = old.track_id;
    select * into new_track from aybee_dashboard.track where id = new.track_id;
    for variant in select * from aybee_dashboard.variant where experiment_id = old.id loop
        RAISE NOTICE 'running trigger for experiment % ---> variant: %', new.name, variant.name;
        perform aybee_dashboard.subtract_percentage_of_variant_to_track(variant, old_track, variant.percent);
        perform aybee_dashboard.add_percentage_of_variant_to_track(variant, new_track, variant.percent);
    end loop;
    return new;
end;
$$ language plpgsql;

grant execute on function aybee_dashboard.add_percentage_of_variant_to_track(
    aybee_dashboard.variant,
    aybee_dashboard.track,
    numeric
) to aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.subtract_percentage_of_variant_to_track(
    aybee_dashboard.variant,
    aybee_dashboard.track,
    numeric
) to aybee_dashboard_loggedin;

drop TRIGGER if exists insert_variant on aybee_dashboard.variant;
CREATE TRIGGER insert_variant
    AFTER INSERT ON aybee_dashboard.variant
    FOR EACH ROW
    EXECUTE PROCEDURE aybee_dashboard.create_variant_to_track();

drop TRIGGER if exists increase_variant_percentage on aybee_dashboard.variant;
CREATE TRIGGER increase_variant_percentage
    AFTER UPDATE ON aybee_dashboard.variant
    FOR EACH ROW
    WHEN (OLD.percent < NEW.percent)
    EXECUTE PROCEDURE aybee_dashboard.increase_variant_to_track();

drop TRIGGER if exists decrease_variant_percentage on aybee_dashboard.variant;
CREATE TRIGGER decrease_variant_percentage
    AFTER UPDATE ON aybee_dashboard.variant
    FOR EACH ROW
    WHEN (OLD.percent > NEW.percent)
    EXECUTE PROCEDURE aybee_dashboard.decrease_variant_to_track();

drop TRIGGER if exists experiment_change_track on aybee_dashboard.experiment;
CREATE TRIGGER experiment_change_track
    AFTER UPDATE ON aybee_dashboard.experiment
    FOR EACH ROW
    WHEN (OLD.track_id is distinct from NEW.track_id and not OLD.segregating and not NEW.segregating)
    EXECUTE PROCEDURE aybee_dashboard.experiment_change_track();
