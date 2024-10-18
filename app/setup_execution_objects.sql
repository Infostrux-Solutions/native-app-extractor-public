create stage if not exists execution.output_stage;
create or replace file format execution.output_file_format type = 'json';

create or replace procedure execution.extract(
    tap object, -- e.g.{ 'spec': 'tap-covid-19' }, can also use `tap-jira`, `tap-github`, ...
    external_access_integration_name string,
    config_secret_qualified_name string,
    catalog_json string,
    state_json string,
    output_file_name string    
)
returns string
language sql
as
$$
declare
    config_json string;
begin

    call core.ensure_pool_exists();
    call core.ensure_pool_active();
    call core.ensure_service_exists();
    call core.set_service_integration(:external_access_integration_name);
    call core.get_secret(:external_access_integration_name, :config_secret_qualified_name) into :config_json;
    
    let result string := (select core.extract(:tap, :config_json, :catalog_json, :state_json, :output_file_name));
    call core.suspend_service();

    return :result;

exception   
    when other then
        call core.suspend_service();
        raise;
end
$$;
