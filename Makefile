SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ifneq (,$(wildcard .env))
include .env
export
endif

COMPOSE            ?= docker compose
COMPOSE_FILE       ?= docker-compose.yml
HELM               ?= helm
KUBECTL            ?= kubectl
ANSIBLE_PLAYBOOK   ?= ansible-playbook
VAGRANT            ?= vagrant

APP_RELEASE        ?= sms-app
MON_RELEASE        ?= app-stack
K8S_NAMESPACE      ?= sms-app
MON_NS             ?= monitoring
KUBECONFIG         ?= $(CURDIR)/kubeconfig/config
HELM_APP_CHART     ?= ./helm-chart
HELM_MON_CHART     ?= ./helm/app-stack
CTRL_IP            ?= 192.168.56.100
APP_VALUES         ?=
MON_VALUES         ?=
SCRIPTS_DIR        ?= $(CURDIR)/scripts
TOOLS_INSTALLER    ?= $(SCRIPTS_DIR)/install-tools.sh
TOOLS_CHECKER      ?= $(SCRIPTS_DIR)/check-tools.sh

export KUBECONFIG

define PRINT_HELP
	@echo "Available targets:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*?##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS=":.*?##"} {printf "  %-28s %s\n", $$1, $$2}'
endef

.PHONY: help
help: ## List targets with descriptions
	$(PRINT_HELP)

# -----------------------------------------------------------------------------
# Bootstrap & validation
# -----------------------------------------------------------------------------
.PHONY: setup
setup: ## Install prerequisite tooling (Debian/Ubuntu hosts)
	@$(TOOLS_INSTALLER)

.PHONY: check
check: ## Validate external tools (docker, kubectl, helm, vagrant, etc.)
	@$(TOOLS_CHECKER)

# -----------------------------------------------------------------------------
# Docker Compose (local development)
# -----------------------------------------------------------------------------
.PHONY: compose-up
compose-up: ## Start the Docker Compose stack in the background
	$(COMPOSE) -f $(COMPOSE_FILE) up -d

.PHONY: compose-down
compose-down: ## Stop the Docker Compose stack
	$(COMPOSE) -f $(COMPOSE_FILE) down

.PHONY: compose-clean
compose-clean: ## Stop the stack and remove named volumes
	$(COMPOSE) -f $(COMPOSE_FILE) down -v

.PHONY: compose-logs
compose-logs: ## Tail Docker Compose logs
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f

.PHONY: compose-ps
compose-ps: ## Show Docker Compose service status
	$(COMPOSE) -f $(COMPOSE_FILE) ps

# -----------------------------------------------------------------------------
# Kubernetes - sms-app Helm chart
# -----------------------------------------------------------------------------
.PHONY: k8s-app-install
k8s-app-install: ## Deploy or upgrade the sms-app Helm chart
	$(HELM) upgrade --install $(APP_RELEASE) $(HELM_APP_CHART) \
		--namespace $(K8S_NAMESPACE) --create-namespace $(APP_VALUES)

.PHONY: k8s-app-uninstall
k8s-app-uninstall: ## Remove the sms-app release
	-$(HELM) uninstall $(APP_RELEASE) --namespace $(K8S_NAMESPACE)

.PHONY: k8s-app-status
k8s-app-status: ## Show pods and services for sms-app
	$(KUBECTL) get pods,svc -n $(K8S_NAMESPACE)

.PHONY: k8s-app-lint
k8s-app-lint: ## Run helm lint/template for sms-app chart
	$(HELM) lint $(HELM_APP_CHART)
	$(HELM) template $(APP_RELEASE) $(HELM_APP_CHART) >/dev/null

# -----------------------------------------------------------------------------
# Kubernetes - monitoring & alerting Helm chart
# -----------------------------------------------------------------------------
.PHONY: k8s-mon-install
k8s-mon-install: ## Deploy or upgrade the monitoring/alerting chart
	$(HELM) upgrade --install $(MON_RELEASE) $(HELM_MON_CHART) \
		--namespace $(MON_NS) --create-namespace $(MON_VALUES)

.PHONY: k8s-mon-uninstall
k8s-mon-uninstall: ## Remove the monitoring/alerting release
	-$(HELM) uninstall $(MON_RELEASE) --namespace $(MON_NS)

.PHONY: k8s-mon-status
k8s-mon-status: ## Show pods and services for monitoring namespace
	$(KUBECTL) get pods,svc -n $(MON_NS)

.PHONY: k8s-mon-lint
k8s-mon-lint: ## Run helm lint/template for monitoring chart
	$(HELM) lint $(HELM_MON_CHART)
	$(HELM) template $(MON_RELEASE) $(HELM_MON_CHART) >/dev/null

# -----------------------------------------------------------------------------
# Kubernetes helpers
# -----------------------------------------------------------------------------
.PHONY: k8s-status
k8s-status: ## Show pods across all namespaces
	$(KUBECTL) get pods -A

.PHONY: k8s-clean
k8s-clean: ## Remove both Helm releases (app + monitoring)
	-$(MAKE) k8s-mon-uninstall
	-$(MAKE) k8s-app-uninstall

.PHONY: rate-limit-test
rate-limit-test: ## Run the Envoy rate limiting smoke test script
	./test-rate-limit.sh

# -----------------------------------------------------------------------------
# Vagrant + Ansible (cluster provisioning)
# -----------------------------------------------------------------------------
.PHONY: cluster-up
cluster-up: ## Boot all Vagrant VMs (controller + workers)
	$(VAGRANT) up

.PHONY: cluster-halt
cluster-halt: ## Halt all Vagrant VMs
	$(VAGRANT) halt

.PHONY: cluster-status
cluster-status: ## Show Vagrant VM status
	$(VAGRANT) status

.PHONY: cluster-destroy
cluster-destroy: ## Destroy all Vagrant VMs (requires CONFIRM=1)
ifndef CONFIRM
	$(error Set CONFIRM=1 to run 'make cluster-destroy')
endif
	$(VAGRANT) destroy -f

.PHONY: cluster-finalize
cluster-finalize: ## Run finalization.yml against the controller node
	@CTRL_KEY=$$(vagrant ssh-config ctrl 2>/dev/null | awk '/IdentityFile/ {print $$2; exit}'); \
	if [ -z "$$CTRL_KEY" ]; then \
		echo "Unable to determine ctrl SSH key. Is the VM running?" >&2; \
		exit 1; \
	fi; \
	echo "Running finalization playbook via $$CTRL_KEY"; \
	$(ANSIBLE_PLAYBOOK) -i $(CTRL_IP), -u vagrant --private-key $$CTRL_KEY \
		--ssh-extra-args="-o StrictHostKeyChecking=no" finalization.yml

.PHONY: cluster-ssh-ctrl
cluster-ssh-ctrl: ## Open an interactive shell on the controller VM
	$(VAGRANT) ssh ctrl


