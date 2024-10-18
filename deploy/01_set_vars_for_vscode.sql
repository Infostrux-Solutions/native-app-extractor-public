-- Configure some session variables

use warehouse compute_wh;
show variables;

declare
  vars RESULTSET;
  var_name VARCHAR;
  stmt VARCHAR;
begin
  vars := (show variables);
  for var in vars do
    var_name := var."name";
    stmt := 'unset ' || var_name;
    execute immediate stmt;
  end for;
  return stmt;
end;

show variables;


-- vars for setting up objects necessary for deployment
set app_prefix = 'infostrux_extractor';

set app_role = $app_prefix || '_role';
set app_warehouse = $app_prefix || '_warehouse';
set app_database = $app_prefix;
set app_name = $app_prefix || '_app';
set app_package_name = $app_prefix || '_package';


set app_under_test = $app_database;


show variables;
