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
