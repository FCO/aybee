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
insert into aybee_dashboard.variant( id, organization_id, experiment_id, name, percent )
    values('b824cff8-77fd-11e8-b5d6-666666666666', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '6f5794f2-77fa-11e8-af51-33e8d37243c0', 'B', .1);
update aybee_dashboard.variant set percent = .02 where id = 'b824cff8-77fd-11e8-b5d6-2f651c118cf6';
update aybee_dashboard.variant set percent = .01 where id = 'b824cff8-77fd-11e8-b5d6-666666666666';
insert into aybee_dashboard.variant( id, organization_id, experiment_id, name, percent )
    values('b824cff8-77fd-11e8-b5d6-888888888888', '979fc2bc-6f54-11e8-a172-7fb168c1de7f', '6f5794f2-77fa-11e8-af51-33e8d37243c0', 'C', .5);

--begin;
--
--set search_path to aybee_dashboard,aybee_private,public;
--
--delete from organization where name = 'org 001';
--
--select register_organization_and_set_claims('org 001', 'admin org 001', 'admin@org001.com', '001');
--
---- RAISE NOTICE "organization id: %", org_id;
--
--table organization;
--table person;
--table account;
--
--select current_setting('jwt.claims.organization_id');
--select register_person('admin2 org 001', 'admin2@org001.com', '001', 't');
--
--rollback;
---- commit;
