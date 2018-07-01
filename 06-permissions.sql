grant usage on schema aybee_dashboard                               to aybee_anonymous, aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.authenticate(text, text)  to aybee_anonymous, aybee_dashboard_loggedin;

grant select, update, insert, delete on table aybee_dashboard.person                to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.organization          to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.platform              to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.track                 to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.experiment            to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variant               to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variant_track         to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variable              to aybee_dashboard_loggedin;
grant select, update, insert, delete on table aybee_dashboard.variable_variant      to aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.logged_user()             to aybee_anonymous, aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.logged_organization()     to aybee_anonymous, aybee_dashboard_loggedin;

grant execute on function aybee_dashboard.register_organization(text, text, text, text)     to aybee_anonymous;
grant execute on function aybee_dashboard._register_person(uuid, text, text, text, bool)    to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_person(text, text, text, bool)           to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_platform(text)                           to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_track(text, text)                        to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.register_experiment(text)                         to aybee_dashboard_loggedin;
--grant execute on function aybee_dashboard.register_experiment(text, text)                   to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_percentage_used(aybee_dashboard.track)      to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_percentage_free(aybee_dashboard.track)      to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.track_free_ranges(aybee_dashboard.track)          to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.copy_track(aybee_dashboard.track)                 to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.segregate_experiment(aybee_dashboard.experiment)  to aybee_dashboard_loggedin;
grant execute on function aybee_dashboard.variant_variables(aybee_dashboard.variant)        to aybee_dashboard_loggedin;

