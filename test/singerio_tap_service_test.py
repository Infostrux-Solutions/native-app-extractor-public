import os
from typing import Generator
from flask import Flask
from flask.testing import FlaskClient
from pytest import fixture
import json
import service.singerio_tap_service as service
from dataclasses import asdict


@fixture
def app():
    return service.app

@fixture
def client(app) -> FlaskClient:
    return app.test_client()


@fixture
def tap():
    return service.Tap(
        spec='https://github.com/meltano/tap-smoke-test/archive/refs/heads/main.zip',
        package_executable='tap-smoke-test')

@fixture
def config_json():
    config_json = """{
      "streams": [
        {
          "stream_name":  "animals",
          "input_filename": "https://gitlab.com/meltano/tap-smoke-test/-/raw/main/demo-data/animals-data.jsonl"
        }
      ]
    }"""
    
    return config_json

@fixture
def catalog_json():
    catalog_json = None
    
    return catalog_json

@fixture
def extract_body(tap, config_json, catalog_json, request):

    result = {
        "data": [
            [0, asdict(tap), config_json, catalog_json, None, request.node.name]
        ]
    }    

    return result


def test_ensure_tap_installed(tap):
    service.ensure_tap_installed(tap)

def test_extract(tap, config_json, catalog_json, request):
    result = service.extract(tap, config_json, catalog_json, None, request.node.name)

    assert result

def test_incremental_extract(tap, config_json, catalog_json, request):
    output_file_name = request.node.name
    
    result = service.extract(tap, config_json, catalog_json, None, output_file_name)
    
    # state is the last line
    output_path = os.path.join(service.output_dir_path, output_file_name)
    with open(output_path, 'r') as result_file:
        result = result_file.read()

    state_json = result.split('\n')[-2]
    result = service.extract(tap, config_json, catalog_json, state_json, request.node.name + "_with_state")

    assert result

def test_extract_handler(client: FlaskClient, extract_body: dict) -> None:
    response = client.post("/extract", json=extract_body)

    assert response.status_code == 200

def test_extract_handler_twice(client: FlaskClient, extract_body: dict) -> None:
    response = client.post("/extract", json=extract_body)
    response = client.post("/extract", json=extract_body)

    assert response.status_code == 200

