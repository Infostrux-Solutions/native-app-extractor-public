use database snowflake; --exists for all roles
use role accountadmin;

-- create role and grants

create role if not exists identifier($app_role);
grant role identifier($app_role) to role accountadmin;
grant role identifier($app_role) to role sysadmin;

set my_user_name = current_user();
grant role identifier($app_role) to user identifier($my_user_name);

grant create warehouse on account to role identifier($app_role);
grant create database on account to role identifier($app_role);
grant create application package on account to role identifier($app_role);
grant create application on account to role identifier($app_role);


grant create compute pool on account to role identifier($app_role) with grant option;
grant bind service endpoint on account to role identifier($app_role) with grant option;

grant create integration on account to role identifier($app_role);



use role identifier($app_role);

-- create a warehouse.
create warehouse if not exists identifier($app_warehouse) with
warehouse_size = 'x-small'
auto_suspend = 180
auto_resume = true
initially_suspended = false;
