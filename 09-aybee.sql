do $$
    declare
        experiment aybee_dashboard.experiment;
    begin
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
        insert into aybee_dashboard.experiment( id, organization_id, track_id, name )
            values('6f5794f2-77fa-11e8-af51-33e8d37243c0', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', 'exp 001');
        insert into aybee_dashboard.variant( id, organization_id, experiment_id, name, percent )
            values('b824cff8-77fd-11e8-b5d6-2f651c118cf6', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '6f5794f2-77fa-11e8-af51-33e8d37243c0', 'A', .01);
        assert (select count(*) from aybee_dashboard.variant_track) = 1;
        assert (select percent_range from aybee_dashboard.variant_track) = '[0,0.01)'::numrange;
        insert into aybee_dashboard.variant( id, organization_id, experiment_id, name, percent )
            values('b824cff8-77fd-11e8-b5d6-666666666666', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '6f5794f2-77fa-11e8-af51-33e8d37243c0', 'B', .1);
        assert (select percent_range from aybee_dashboard.variant_track order by 1 desc limit 1) = '[0.01,0.11)'::numrange;
        update aybee_dashboard.variant set percent = .02 where id = 'b824cff8-77fd-11e8-b5d6-2f651c118cf6';
        assert (select percent_range from aybee_dashboard.variant_track order by 1 desc limit 1) = '[0.11,0.12)'::numrange;
        update aybee_dashboard.variant set percent = .01 where id = 'b824cff8-77fd-11e8-b5d6-666666666666';
        assert (select percent_range from aybee_dashboard.variant_track where variant_id = 'b824cff8-77fd-11e8-b5d6-666666666666' limit 1) = '[0.01,0.02)'::numrange;
        insert into aybee_dashboard.variant( id, organization_id, experiment_id, name, percent )
            values('b824cff8-77fd-11e8-b5d6-888888888888', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '6f5794f2-77fa-11e8-af51-33e8d37243c0', 'C', .5);
        assert (select count(*) from aybee_dashboard.variant_track where variant_id = 'b824cff8-77fd-11e8-b5d6-888888888888') = 2;
        assert (
            select
                percent_range
            from
                aybee_dashboard.variant_track
            where
                variant_id = 'b824cff8-77fd-11e8-b5d6-888888888888'
            order by 1
            limit 1
            offset 0
            ) = '[0.02,0.11)'::numrange;
        assert (
            select
                percent_range
            from
                aybee_dashboard.variant_track
            where
                variant_id = 'b824cff8-77fd-11e8-b5d6-888888888888'
            order by 1
            limit 1
            offset 1
            ) = '[0.12,0.53)'::numrange;
        select * into experiment from aybee_dashboard.experiment where id = '6f5794f2-77fa-11e8-af51-33e8d37243c0';
        perform aybee_dashboard.segregate_experiment(experiment);
        assert (
            select
                count(*)
            from
                aybee_dashboard.variant_track
            where
                track_id = '979fc2bc-6f54-11e8-a172-7fb168c1de7f'
            ) = 0;
        assert (
            select
                count(*)
            from
                aybee_dashboard.variant_track
            ) = 5;
    end;
$$
