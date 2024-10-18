-- drop schema core;
-- create or replace schema core;


create or replace procedure core.pool_name()
returns varchar
language sql
as
$$
    begin
        let pool_name := (select current_database()) || '_COMPUTE_POOL';
        return :pool_name;
    end
$$;


create or replace procedure core.ensure_pool_exists()
returns string
language sql
as
$$
    declare
        pool_name varchar;
    begin
        call core.pool_name() into :pool_name;

        create compute pool if not exists identifier(:pool_name)
            instance_family = cpu_x64_xs 
            min_nodes = 1
            max_nodes = 1                
            auto_resume = true
            initially_suspended = true -- default: false
            auto_suspend_secs = 60 -- default: 3600 seconds
            comment = 'used by native app';
    end
$$;


create or replace procedure core.pool_status()
returns varchar
language sql
as
$$
    declare
        pool_name varchar;
        pool_status varchar;
    begin
        call core.pool_name() into :pool_name;
        call system$get_compute_pool_status(:pool_name) into :pool_status;
        return :pool_status;
    end
$$;



create or replace procedure core.ensure_pool_active()
returns string
language sql
as
$$
    declare
        counter number(8, 0) := 0;  -- loop counter.
        max_seconds integer := 200; -- adjust as needed
        wait_seconds integer := 10; -- adjust as needed
        status string;
        pool_name varchar;
        pool_status varchar;
    begin
        call core.ensure_pool_exists();
        call core.pool_name() into :pool_name;

        while (:counter < :max_seconds) do
            call core.pool_status() into :pool_status;
            pool_status := parse_json(:pool_status)['status']::varchar;

            if (:pool_status in ('SUSPENDED')) THen
                alter compute pool identifier(:pool_name) resume; 
            end if;
            if (:pool_status in ('ACTIVE', 'IDLE')) then
                return 'READY status: `' || :pool_status || '` after ' || cast(counter as varchar) || ' seconds';
            else
                -- wait for 30 seconds (adjust as needed)
                call system$wait(:wait_seconds, 'SECONDS');
            end if;        
            counter := :counter + :wait_seconds;
        end while;
        return 'NOT READY status: `' || :pool_status || '` after ' || cast(counter as varchar) || ' seconds';;
    end;
$$;


-- When you suspend a compute pool, Snowflake suspends all services in that compute pool, 
-- but the jobs continue to run until they reach a terminal state (DONE or FAILED), 
-- after which the compute pool nodes are released.
create or replace procedure core.suspend_pool()
returns table()
language sql
as $$
    declare 
        pool_name varchar;
    begin
        call core.pool_name() into :pool_name;
        alter compute pool identifier(:pool_name) suspend; 
        let results resultset := (select * from table(result_scan(last_query_id())));
        return table(results);
    end; 
$$;



-------------------
-- Service functions
--------------------

create or replace procedure core.ensure_service_exists()
returns string
language sql
as
$$
    declare
        pool_name varchar;
    begin
        call core.ensure_pool_exists();

        call core.pool_name() into :pool_name;

        create service if not exists core.singerio_tap_service
            in compute pool identifier(:pool_name)
            from specification '
spec:
  containers:
  - name: echo
    image: /infostrux_extractor/image_repository_schema/image_repository_stage/infostrux_extractor_image:latest

    env:
      SERVER_PORT: 8000
      
    readinessProbe: 
      port: 8000 
      path: /healthcheck

    volumeMounts:
    - name: output
      mountPath: /service/output

  endpoints:
  - name: service
    port: 8000
    public: false

  volumes:                               # optional volume list
  - name: output
    source: "@execution.output_stage"
     
';

    create or replace function core.extract(
        tap object, 
        config_json string, 
        catalog_json string, 
        state_json string, 
        output_file_name string)
    returns varchar
    service=core.singerio_tap_service
    endpoint=service
    as '/extract'; --this is the invocation url of the proxy service (e.g. api gateway or api management service) and resource through which snowflake calls the remote service.

    return 'Service successfully created.';

end
$$;

create or replace procedure core.service_status()
returns varchar
language sql
execute as owner
as $$
    declare
        service_status varchar;
    begin
        call system$get_service_status('core.singerio_tap_service') into :service_status;
        return :service_status;
        --return parse_json(:service_status)[0]['status']::varchar;
    end; 
$$;

-- When you suspend a service or a job service, Snowflake SHUTS DOWN and DELETES the containers. 
-- If you later resume a suspended service,Snowflake recreates the containers. 
-- That is, Snowflake takes the image from your repository and starts the containers. 
-- Note that, Snowflake deploys the same image version; it is not a service update operation.

-- When you invoke a suspended service using either a service function 
-- or invoking the public endpoint (ingress), Snowflake automatically resumes the service.
create or replace procedure core.suspend_service()
returns varchar
language sql
as $$
    declare
        service_status varchar;
    begin
        alter service if exists core.singerio_tap_service suspend; 
        call system$get_service_status('core.singerio_tap_service') into :service_status;
        return :service_status;
        --return parse_json(:service_status)[0]['status']::varchar;
    end; 
$$;

create or replace procedure core.set_service_integration(external_access_integration_name string)
returns string
language python
runtime_version = '3.11'
packages = ('snowflake-snowpark-python')
handler = 'run'
as
$$
def run(session, external_access_integration_name):

    sql_txt = f'''
        alter service if exists core.singerio_tap_service
        set external_access_integrations = ({external_access_integration_name})
        '''
    session.sql(sql_txt).collect()

    return 'Intergration set.'
$$;

create or replace procedure core.get_secret(
    external_access_integration_name string,
    secret_qualified_name string
)
returns string
language python
runtime_version = '3.11'
packages = ('snowflake-snowpark-python')
handler = 'run'
as
$$
def run(session, external_access_integration_name, secret_qualified_name):

    quoted_external_access_integration_name = external_access_integration_name.replace('"', '""')
    quoted_secret_qualified_name = secret_qualified_name.replace('"', '""')
    function_name = f'"get_string__{quoted_external_access_integration_name}__{quoted_secret_qualified_name}"'

    double_dollar = "$" + "$"

    sql_txt = f"""
create or replace function core.{function_name}()
returns string
language python
runtime_version = 3.8
handler = 'get_secret'
external_access_integrations = ({external_access_integration_name})
secrets = ('cred' = {secret_qualified_name} )
as
{double_dollar}
import _snowflake

def get_secret():
  secret_type = _snowflake.get_generic_secret_string('cred')
  return secret_type
{double_dollar}    
"""

    session.sql(sql_txt).collect()

    sql_txt = f'''select core.{function_name}()'''
    result = session.sql(sql_txt).collect()[0][0]

    return result

$$;
