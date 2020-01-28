create  schema if not exists aybee;
create  schema if not exists aybee_private;
create  schema if not exists aybee_dashboard;
create  schema if not exists aybee_metrics;

create  extension if not exists "uuid-ossp";
create  extension if not exists "pgcrypto";
create  extension if not exists "btree_gist";
create  extension if not exists "hashlib";
alter   default privileges revoke execute on functions from public;

create  role aybee_postgraphile login password 'xyz';
create  role aybee_anonymous login password 'abc';
create  role aybee_dashboard_loggedin;
create  role aybee_metric_writer login password '123';
grant   aybee_anonymous             to aybee_postgraphile;
grant   aybee_dashboard_loggedin    to aybee_postgraphile;

