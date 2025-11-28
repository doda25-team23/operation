## Week 1
### Team:
No work on the repository.
-------------------------------------------------------------------------------------------------------------------------
## Week 2 A1
### Radu
For F9, we added an automated workflow that trains the SMS classifier and publishes the model artifacts as versioned GitHub Releases. For F10, the model-service was updated to load its model externally, downloading it at startup if missing and caching it in a mounted directory.
Links: https://github.com/doda25-team23/model-service/pull/1, https://github.com/doda25-team23/model-service/pull/3

### Ocean
F7 & F8:
Created Docker compose setup in operation repository. The .yml file orchestrates the frontend (9090) and model-service (8081) microservices, pulling from GH container registry. README.m provides a guide for starting including links to all repos. GH actions workflow is implemented for automated releases, App workflow triggers automatically on pushes to main and extracts versions from pom.xml metadata. The modelservice workflow triggers on Git tags. Both publish versioned and :latest images to GH container registry.

### Cristian

### Brewen

-------------------------------------------------------------------------------------------------------------------------
## Week 3 A2
### Radu
Implemented the general.yaml playbook to prepare all cluster nodes with the required base configuration (SSH access, swap disable, kernel modules, sysctl settings, Kubernetes packages, and fully configured containerd). The playbook was tested on node-1 and ran successfully end-to-end using ansible_local via Vagrant. This ensures all machines are ready for the controller/worker setup steps.

### Ocean
VM insfrastructure setup, Vagrantfile that provisions 1 control node and 2 worker nodes running Ubuntu 24.04. Setup includes NAT and host-only networking, has local ansible provisioners for cross-platform, a shared folder for kubeconfig export, and placeholder Ansible playbooks for Radu to work in. Added my SSH key to folder. .



