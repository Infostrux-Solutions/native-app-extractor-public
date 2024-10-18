Infostrux Extractor
===================

# Introduction

The Infostrux Extractor app is a universal data ingest solution. It extracts data given a Singer.io tap specification (e.g., "tap-covid-19" or "tap-jira") and its configuration. The app works with a wide variety of taps that support the protocol.

The app provides a stored procedure that runs the tap and saves the output to a file on a Snowflake stage. The raw extracted data conforms to [Singer open-source standard](https://github.com/singer-io/getting-started). Once the data is extracted, the Infostrux Loader app or other loading mechanisms can be used to load the data into structured tables.

# Installation

## Prequisites

- bash
- git
- make
- docker
- python3.10
- [snow cli](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) including `~/.snowflake/config.toml` file with default connection. Test it by running `snow connection test` in bash. The connection needs to have `ACCOUNTADMIN` role, as it will be used to create a role, warehouse, compute pool, and database with extractor services and stored procs as well as very permissive test integration.


## Security Note

Review the scripts in 'deploy/' and 'app/' directories, paying special attention to security. 

The app is very powerful as it allows the user to install and run any Python code from PyPi or other sources. Once installed, be careful when granting usage privileges. It is recommended not to use the role nor the app's objects directly. Rather, create and grant wrapper stored procs that run the extractor with a select Python package only.

## Deploy to Snowflake

To deploy the objects to your Snowflake account, run 

```

git clone https://github.com/Infostrux-Solutions/native-app-extractor-public.git

cd native-app-extractor-public

chmod 744 deploy/*.sh

make install
```

## Uninstall

Run

```
make uninstall
```

The script will remove all databases, compute pools, warehouses, roles, etc. that were created or used by the installation scripts.

# Usage

See [app/README.md](app/README.md).
