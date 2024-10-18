use database identifier($app_under_test);

-- drop service  if exists core.singerio_tap_service;
call execution.extract(
    { 'spec': 'https://github.com/meltano/tap-smoke-test/archive/refs/heads/main.zip', 'package_executable': 'tap-smoke-test' },
    $test_external_integration,
    $test_tap_config_secret,
    null,
    null,
    'execution_smoke_test'
);

select "SYSTEM$GET_SERVICE_LOGS"($app_under_test || '.core.singerio_tap_service', 0, 'echo', 100);  --noqa

list @execution.output_stage;
select *, row_number() over (order by 'a') 
from @execution.output_stage/execution_smoke_test (file_format => 'execution.output_file_format');
remove @execution.output_stage/execution_smoke_test;

call core.service_status();
call core.suspend_service();
