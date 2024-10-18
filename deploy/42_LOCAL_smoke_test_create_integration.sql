set test_database = $app_prefix || '_test';

set test_external_integration = $test_database || '_external_access_integration';
set test_integrations_schema = $test_database || '.integrations_schema';
set test_network_rule = $test_integrations_schema || '.egress_all_https_rule';
set test_tap_config_secret = $test_integrations_schema || '.tap_config_secret';

use role identifier($app_role);
use warehouse identifier($app_warehouse);
create database if not exists identifier($test_database);
use database identifier($test_database);

-- create schma that will hold the secrets and network rules for the external access integration
create schema if not exists identifier($test_integrations_schema);
use schema identifier($test_integrations_schema);

-- create tap's `config.json` as a secret
create or replace secret identifier($test_tap_config_secret)
    type = generic_string
    secret_string  = $${
      "streams": [
        {
          "stream_name":  "animals",
          "input_filename": "https://gitlab.com/meltano/tap-smoke-test/-/raw/main/demo-data/animals-data.jsonl"
        }
      ]
}$$;


describe secret identifier($test_tap_config_secret); -- noqa


-- create an egress network rule so the container can access public apis 
create or replace network rule 
  identifier($test_network_rule)
    type = 'host_port'
    mode= 'egress'
    value_list = ('0.0.0.0:443') ;  -- !!! DO NOT USE IN PRODUCTION! modify to provide access only to what's needed
    --value_list = ('pypi.org:443', 'pythonhosted.org:443', 'files.pythonhosted.org:443', ' github.com:443') ;
describe network rule identifier($test_network_rule);


-- create external access integrations
create or replace external access integration identifier($test_external_integration)
    allowed_network_rules = ( egress_all_https_rule )
    allowed_authentication_secrets = (tap_config_secret)  -- !!! modify as needed
    enabled = true;
describe integration identifier($test_external_integration);
