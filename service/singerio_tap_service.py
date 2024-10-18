import json.tool
import logging
import os
import sys
import json
import subprocess
import tempfile
from dataclasses import dataclass


SERVICE_HOST = os.getenv('SERVER_HOST', '0.0.0.0')
SERVICE_PORT = os.getenv('SERVER_PORT', 8080)

BASE_FOLDER = os.path.dirname(os.path.abspath(__file__)) 
TAPS_FOLDER_PATH = os.path.join(BASE_FOLDER,"taps")


# ##### BEGIN Flask functions
from flask import Flask
from flask import request
from flask import make_response
from flask import render_template

app = Flask(__name__)


def get_logger(logger_name: str) -> logging.Logger:
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.DEBUG)
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(
        logging.Formatter(
            '%(name)s [%(asctime)s] [%(levelname)s] %(message)s'))
    logger.addHandler(handler)
    return logger

logger = get_logger('service')


@app.get("/healthcheck")
def healthcheck_handler() -> str:
    return "I'm ready!"

@app.post("/extract")
def extract_handler() -> str:
    """
    Extract handler for input data sent by Snowflake.

    The input format follows https://docs.snowflake.com/en/sql-reference/external-functions-data-format#body-format
    i.e. 

    {
        "data": [
            [<row number>, arg1, arg2, arg3]
        ]
    }

    For extraction, We are not supporting user defined table functions (UDTFs), only UDFs. 
    The expected args are 

    tap: object of the form 
        {
            "spec": "<tap specification e.g. tap-covid-19>", 
            "package_executable": "<optional name of the executable provided by the python package. usually, this is the same as the name of the package by not always>",
            "suffix": "<optional suffix instruction to pipx, so that different versions of the same package can be installed. e.g. 3.0>"
        }

    config_json: "<json string containing the tap config>",
    catalog_json: "<json string containing the tap catalog>",

    Hence, the expected payload is:

    {
        "data": [
            [0, {"spec": "<spec>", ...}, "<config_json>", "<catalog_json>"]
        ]
    }


    """
    logger.debug(f'Request json:\n{json.dumps(request.json, indent=4)}')

    request_json = request.json
    assert request_json

    data = request_json.get("data", None)
    assert data
    assert len(data) == 1

    params = data[0]

    tap_dict = params[1]
    tap = Tap(**tap_dict)

    config_json = params[2]
    if isinstance(config_json, dict):
        config_json = json.dumps(config_json)

    catalog_json = params[3]
    if isinstance(catalog_json, dict):
        catalog_json = json.dumps(catalog_json)

    state_json = params[4]
    if isinstance(state_json, dict):
        state_json = json.dumps(state_json)

    output_file_name = params[5]

    response = extract(tap, config_json, catalog_json, state_json, output_file_name)

    logger.debug(f'Reponding with: {response}')
    return { "data": [[0, response]]}

####### service ##############

@dataclass
class Tap:

    def __init__(
            self, 
            spec: str, 
            package_executable: str = None, 
            suffix: str = None,
            config_option: str = "--config",
            catalog_option: str = "--catalog",
            state_option: str = "--state"):
        
        self.spec = spec
        self.package_executable = package_executable or spec
        self.suffix = suffix or ""
        self.config_option = config_option
        self.catalog_option = catalog_option
        self.state_option = state_option

    spec: str
    package_executable: str
    suffix: str
    config_option: str
    catalog_option: str
    state_option: str
    
    @property
    def executable (self): return self.package_executable + self.suffix


output_dir_path = "output"


def extract(
        tap: Tap,
        config_json: str,
        catalog_json: str,
        state_json: str,
        output_file_name) -> str:
    
    ensure_tap_installed(tap) 

    result = ''

    with tempfile.NamedTemporaryFile() as config_file:
        with tempfile.NamedTemporaryFile() as catalog_file:
            with tempfile.NamedTemporaryFile() as state_file:

                command_line = [tap.executable]

                if config_json:
                    logger.debug(f"Creating temp config file '{config_file.name}'")
                    config_file.write(str.encode(config_json))
                    config_file.flush()

                    command_line += [tap.config_option, config_file.name]

                if catalog_json:
                    logger.debug(f"Creating temp catalog file '{catalog_file.name}'")
                    catalog_file.write(str.encode(catalog_json))
                    catalog_file.flush()

                    command_line += [tap.catalog_option, catalog_file.name]

                if state_json:
                    logger.debug(f"Creating temp state file '{state_file.name}'")
                    state_file.write(str.encode(state_json))
                    state_file.flush()

                    command_line += [tap.state_option, state_file.name]

                result = run_shell(" ".join(command_line))  

    os.makedirs(output_dir_path, exist_ok=True)
    output_path = os.path.join(output_dir_path, output_file_name)
    with open(output_path, "w") as output_file:
        output_file.write(result)

    return 'Successfully extrtacted data.'


def ensure_tap_installed(tap: Tap) -> None:

    suffix_option = "" if not tap.suffix else f"--suffix {tap.suffix}"

    # Perform default setup with `pipx`
    run_shell(f"pipx install {suffix_option} {tap.spec}")
    run_shell(f"{tap.executable} --help")


def run_shell(command: str) -> str:
    logger.debug(f"Going to run shell command '{command}'")
    result = subprocess.check_output(command, shell=True, text=True)
    logger.debug(f"Shell command '{command}' returned:\n{result}")

    return result


if __name__ == '__main__':
    os.chdir(BASE_FOLDER)

    app.run(host=SERVICE_HOST, port=SERVICE_PORT)
