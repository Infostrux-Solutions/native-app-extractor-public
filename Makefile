SHELL := bash

NAME := service
BOOTSTRAP_PYTHON := python3.10

VENV := $(shell echo $${ENV_FOLDER-.venv})
VENV_PYTHON := $(VENV)/bin/python
VENV_PACKAGES_STAMP := $(VENV)/.install.stamp
VENV_ACTIVATE := source ${VENV}/bin/activate

# This will output the help for each task
.PHONY: help
help: ## List available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


.PHONY: venv
venv: $(VENV)  				## Build empty Python venv where all dependencies will be installed
$(VENV):
	@if [ -z $(BOOTSTRAP_PYTHON) ]; then echo "$(BOOTSTRAP_PYTHON) could not be found."; exit 2; fi
	$(BOOTSTRAP_PYTHON) -m venv $(VENV)

.PHONY: venv_packages
venv_packages: $(VENV_PACKAGES_STAMP)  ## Build venv and install all dependencies including installing the 'service' python package locally to enable local development
$(VENV_PACKAGES_STAMP): $(VENV) pyproject.toml
	$(VENV_ACTIVATE) && pip install -e .[dev,test]
	touch $(VENV_PACKAGES_STAMP)

.PHONY: code
code: $(VENV_PACKAGES_STAMP)
	$(VENV_ACTIVATE) && code . --no-sandbox


.PHONY: shell
shell: $(VENV_PACKAGES_STAMP)		## Start shell from an activated Python venv with all dependencies in place
	$(VENV_ACTIVATE) && bash -i

.PHONY: service
service: $(VENV_PACKAGES_STAMP)
	$(VENV_ACTIVATE) && python3 service/singerio_tap_service.py

.PHONY: install
install: $(VENV_PACKAGES_STAMP)		## Creates INFOSTRUX_EXTRACTOR* role, warehouse, compute_pool and database that holds extractor stored procs, as well as smoke test integration and databases
	$(VENV_ACTIVATE) && ./deploy/830_LOCAL_deploy_test.sh	

.PHONY: uninstall
uninstall: $(VENV_PACKAGES_STAMP)	## Removes INFOSTRUX_EXTRACTOR* role, warehouse, compute_pool, integrations and databases that were created or used during installation
	$(VENV_ACTIVATE) && ./deploy/70_PROVIDER_drop_objects.sh	



.PHONY: test
test: $(VENV_PACKAGES_STAMP)		## Run tests
	$(VENV_ACTIVATE) && pytest



.PHONY: clean
clean:
	rm -rf $(VENV)