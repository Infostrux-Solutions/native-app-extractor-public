use database snowflake; --exists for all roles
use role accountadmin;


----------------------

drop database if exists infostrux_extractor;


-- if services are running, drop compute pool command will fail.
-- you can run alter compute pool … stop all, which drops both services and jobs.
-- you can also use the drop service command to drop individual services.
alter compute pool if exists infostrux_extractor_compute_pool stop all;
drop compute pool if exists infostrux_extractor_compute_pool;

drop database if exists infostrux_extractor_test;
drop external access integration if exists infostrux_extractor_test_external_access_integration;

drop warehouse if exists infostrux_extractor_warehouse;
drop role if exists infostrux_extractor_role;


--- verify everything is gone
show warehouses like 'infostrux_extractor%' in account;
show databases like 'infostrux_extractor%' in account;
show compute pools like 'infostrux_extractor%' in account;
show security integrations like 'infostrux_extractor%';
show api integrations like 'infostrux_extractor%';
show integrations like 'infostrux_extractor%';
show roles like 'infostrux_extractor%' in account;

show applications like 'infostrux_extractor%' in account;
show application packages like 'infostrux_extractor%' in account;
