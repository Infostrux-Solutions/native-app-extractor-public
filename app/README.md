Infostrux Extractor
===================

# Introduction

The Infostrux Extractor app is a universal data ingest solution. It extracts data given a Singer.io tap specification (e.g., "tap-covid-19" or "tap-jira") and its configuration. The app works with a wide variety of taps that support the protocol.

The app provides a stored procedure that runs the tap and saves the output to a file on a Snowflake stage. The raw extracted data conforms to [Singer open-source standard](https://github.com/singer-io/getting-started). Once the data is extracted, the Infostrux Loader app or other loading mechanisms can be used to load the data into structured tables.

# EXTRACT() Stored Procedure

The application exposes `EXTRACT` stored procedure in the `EXECUTION` schema. Assuming that the installed application is called `INFOSTRUX_EXTRACTOR`, the function signature is:

```SQL
INFOSTRUX_EXTRACTOR.EXECUTION.EXTRACT(
   tap object, 
   external_access_integration_name string,
   config_secret_qualified_name string,
   catalog_json string,
   state_json string,
   output_file_name string
)
RETURNS STRING

```

Where

*tap* is an object of the form:
```json
       {
           "spec": "<Tap specification e.g. tap-covid-19. 
The tap specification can be a PyPi package
or an https:// url of tap’s package git repo>",
           "package_executable": "<Optional name of the executable 
provided by the Python package. 
Usually, this is the same as 
the name of the package by not always>",
           "suffix": "<Optional suffix, so that different versions 
of the same package can be installed. e.g. 3.0>"
       }

```

**external_access_integration_name** is the name of the external access integration that allows access to the data source being extracted. It must also allow outbound traffic to PyPi or the git repository. 

**config_secret_qualified_name** is a fully qualified name of the secret that holds the taps config. 

**catalog_json** is an optional string holding the JSON of the catalog to be used by the tap. The initial catalog can be obtained by running a tap on the local machine in discovery mode. Some taps accept null. See the documentation of individual taps for instructions. The catalogs can be edited to enable or disable different streams that the tap extracts.

**state_json** is an optional string holding the JSON of the state as provided by the previous run. The state can be used for incremental extraction by the taps that support it. Usually, the tap’s successful run produces the state that will result in incremental extraction on the next run

**output_file_name** is the name of the file that holds the results. The file can be found on `@execution.output_stage`.

## Notes

The first run of the stored procedure may take 3-5 minutes even for trivial extraction. The stored procedure instantiates and starts a Snowpark Container Services compute pool and the Snowpart Container Service service. 

Upon completion, the stored procedure suspends the service, which, in approximately 5 minutes, will lead to the suspension of the compute pool. The service is restarted when the next call to `EXTRACT()` is made. Within the suspension interval, the second call to `EXTRACT()` usually takes 30 seconds + the extraction time. The second call to `EXTRACT()` after the suspension may again take ~3 mins + the extraction time.
The raw extracted data conforms to [Singer open-source standard](https://github.com/singer-io/getting-started). Once the data is extracted, the Infostrux Loader app (free on Snowflake marketplace) or other loading mechanisms can be used to load the data into structured tables.

# Example Configuration and Execution

The application needs to be configured by:
- granting `use` on an external access integration that allows access to data source end-points as well as access to PyPi or git repositories that host the tap
- granting `read` on configuration secret
- granting `create compute pool` and `bind service endpoint` privileges so the app can create the Snowpark Container Service resources to run the extraction 

Here is a script for that purpose. Please edit the settings as appropriate and review all places in the script marked with "!!!" that may need to be adjusted if settings are modified:

```SQL
use role accountadmin;

-- !!! update to your warehouse
use warehouse compute_wh;

-----------------------------------------
-- BEGIN configure some session variables

-- !!! choose the tap you want to install (see https://singer.io)
set mytap_name = 'tap-covid-19';

-- !!! set to the name of the application as installed in your account
set myapp_name = 'INFOSTRUX_EXTRACTOR_APP';

set myapp_database = $myapp_name || '_DB';
set myapp_integrations_schema = $myapp_database || '.INTEGRATIONS_SCHEMA';
set myapp_network_rule = $myapp_integrations_schema || '.EGRESS_ALL_HTTPS_RULE';
set myapp_external_integration = $myapp_name || '_external_access_integration';
set myapp_config_secret = $myapp_integrations_schema || '.tap_covid_19_config_json';

-- END configure some session variables
---------------------------------------

-----------------------------------------------------------------------_-
-- BEGIN create EXTERNAL ACCESS INTEGRATION with SECRET for 'config_json'

create database if not exists identifier($myapp_database);
create schema if not exists identifier($myapp_integrations_schema);
use schema identifier($myapp_integrations_schema);

-- !!! create tap's `config.json` as a secret
-- !!! in this example, we use a not-so-secret token that can only access public git repos that are accessible anyways
-- !!! replace the api_token with your own that can only access public git repos that are accessible anyways",
create or replace secret identifier($myapp_config_secret)
   type = generic_string
   secret_string  = $${
     "api_token": "!!!<your token here>",
     "start_date": "2019-01-01T00:00:00",
     "user_agent": "infostrux_extractor"
   }$$;

describe secret identifier($myapp_config_secret); -- noqa

-- create an EGRESS NETWORK RULE so the container can access public APIs
create or replace network rule
 identifier($myapp_network_rule)
   type = 'host_port'
   mode= 'egress'
   value_list = ('0.0.0.0:443') ;  -- !!! DO NOT USE IN PRODUCTION! modify to provide access only to what's needed
describe network rule identifier($myapp_network_rule);

-- create EXTERNAL ACCESS INTEGRATIONS
use schema identifier($myapp_integrations_schema);
create or replace external access integration identifier($myapp_external_integration)
   allowed_network_rules = ( egress_all_https_rule )
   allowed_authentication_secrets = (tap_covid_19_config_json)  -- !!! modify as needed
   enabled = true;
describe integration identifier($myapp_external_integration);

-- END Create EXTERNAL ACCESS INTEGRATION with SECRET for 'config_json'
-----------------------------------------------------------------------

----------------------------
-- BEGIN cleanup integrations and secrets.
-- NOTE: Deleting these may make the app unusable

-- drop integration if exists identifier($myapp_external_integration);
-- drop schema if exists identifier($myapp_integrations_schema);

-- Optionally, delete the database if there isn't any data worth keeping
-- drop database if exists identifier($myapp_database);
-- END cleanup integrations and secrets.
----------------------------

-----------------------------------------------------------
-- BEGIN Grant privileges to the app
grant create compute pool on account to application identifier($myapp_name);
grant bind service endpoint on account to application identifier($myapp_name);

grant usage on database identifier($myapp_database) to application identifier($myapp_name);
grant usage on schema identifier($myapp_integrations_schema) to application identifier($myapp_name);

grant usage on integration identifier($myapp_external_integration) to application identifier($myapp_name);
grant read on secret identifier($myapp_config_secret) to application identifier($myapp_name);
-- END Grant privileges to the app
---------------------------------------------------------

use database identifier($myapp_name);

-- this procedure creates the compute pool, instantiates the service, and creates the service function, if needed.
-- it may take a couple of minutes for the COMPUTE POOL to be provisioned and ACTIVE
call execution.extract(
   { 'spec': $mytap_name },
   $myapp_external_integration,
   $myapp_config_secret,
   -- !!! modify the catalog as needed
   $${
     "streams": [
       {
         "tap_stream_id": "c19_trk_us_states_current",
         "key_properties": ["__sdc_row_number"],
         "schema": {
           "_comment": "Must enable this streams schema by adding `selected: true,`",       
           "selected": true,
           "properties": {
             "__sdc_row_number": {"type": ["null", "integer"]},
             "state": {"type": ["null", "string"]},
             "positive": {"type": ["null", "integer"]},
             "last_update_et": {"type": ["null", "string"]}
           },
           "type": ["null", "object"],
           "additionalProperties": false
         },
         "stream": "c19_trk_us_states_current",
         "metadata": []
       }   
     ]
   }$$,
   null,
   'app_execution_extract_test'
);

-- Verify the output

list @execution.output_stage;
select *, row_number() over (order by 'a') from @execution.output_stage/app_execution_extract_test (file_format => 'execution.output_file_format');
remove @execution.output_stage/app_execution_extract_test;

```

Follow https://github.blog/security/application-security/introducing-fine-grained-personal-access-tokens-for-github/ for instructions on how to obtain a GitHub token with read-only access to private repositories. The token is needed for tap-covid-19 to work.

# Notes

## Access notes

As shown in the example configuration script above, The application needs to be configured by:
- granting `use` on an external access integration that allows access to data source end-points as well as access to PyPi or git repositories that host the tap
- granting `read` on configuration secret
- granting `create compute pool` and `bind service endpoint` privileges so the app can create the Snowpark Container Service resources to run the extraction 

Note that once the secrets are granted and the application is initialized, anybody who has usage permissions on the app will be able to extract and read the data from the data source without requiring permissions for integration and/or secrets themselves. The grantors will not be able to read the secrets or use the integration themselves unless they are granted to them explicitly elsewhere.

## How to uninstall
The application can be uninstalled, and all resources owned by it, including the compute pool and the service dropped by running:

```SQL
drop application identifier($myapp_name) cascade;

```

