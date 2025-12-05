## Week 1

### Team:

No work on the repository.

## Week 2 A1

### Radu

For F9, we added an automated workflow that trains the SMS classifier and publishes the model artifacts as versioned GitHub Releases. For F10, the model-service was updated to load its model externally, downloading it at startup if missing and caching it in a mounted directory.
Links: https://github.com/doda25-team23/model-service/pull/1, https://github.com/doda25-team23/model-service/pull/3

### Ocean

F7 & F8:
Created Docker compose setup in operation repository. The .yml file orchestrates the frontend (9090) and model-service (8081) microservices, pulling from GH container registry. README.m provides a guide for starting including links to all repos. GH actions workflow is implemented for automated releases, App workflow triggers automatically on pushes to main and extracts versions from pom.xml metadata. The modelservice workflow triggers on Git tags. Both publish versioned and :latest images to GH container registry.

--Made the mistake to work directly on main, the commits:
Operations:
7a8a6bccb1a542fb1949921de8db633e852b3712, 3dfcf23bda2237a3ae9e35dacf3fa2b85a075608
App:
878e39172c555919bc2941d71915620aa7420a39
cfa73a015e397bec9a3b031944601849e95d06e0
Model-service:
484051246dc9e7cb103f8835c8628609df74da10
35a0fe5b8024c74333ac3a547ba96519b31fb81f

### Cristian

F3–F6 & small F10 adjustments:

Implemented full containerization and release engineering for both the app and model-service microservices. Added a multi-stage Dockerfile for the app and a flexible, volume-based Dockerfile for the model-service, supporting dynamic ports and external model loading. Set up GitHub Actions workflows in both repositories to automatically build and publish multi-architecture images (amd64/arm64) to the GitHub Container Registry, using tag-based version extraction for model-service and metadata-based versioning for the app. Made both services expose configurable ports and read required configuration through environment variables, making them fully composable and production-ready.

App commits: 6f35491, a12f979, 1294c61
Model-service commits: 2f712b8
Operation commits: 355f920

### Brewen

Delivered F1–F2 by creating the reusable `lib-version` Maven module with a `VersionUtil` class that reads packaged meta-data, exposing the version to the `app` service and wiring in a GitHub Actions workflow that builds/tests the library, tags releases, and publishes to GitHub Packages. Also owned F10–F11: updated `model-service` to fetch its model at startup via a mounted volume instead of bundling it, and extended the release automation so stable releases bump from the current `*-SNAPSHOT` while every branch build produces a timestamped pre-release artifact.

---

## Week 3 A2

### Radu

Implemented the general.yaml playbook to prepare all cluster nodes with the required base configuration (SSH access, swap disable, kernel modules, sysctl settings, Kubernetes packages, and fully configured containerd). The playbook was tested on node-1 and ran successfully end-to-end using ansible_local via Vagrant. This ensures all machines are ready for the controller/worker setup steps.
Link: https://github.com/doda25-team23/operation/pull/3

### Ocean

VM insfrastructure setup, Vagrantfile that provisions 1 control node and 2 worker nodes running Ubuntu 24.04. Setup includes NAT and host-only networking, has local ansible provisioners for cross-platform, a shared folder for kubeconfig export, and placeholder Ansible playbooks for Radu to work in. Added my SSH key to folder.

--Made the mistake to work directly on main, the commits:
802a102c62a07a8be3d3859ccb6abe34670a4e5b
88eb0033b642c3bd320f3b9bb2b04b5ad23dffd4
3abc237a82f0ed1364b80e528f26a1eceae032c3


### Cristian

Implemented the Kubernetes cluster setup playbooks (ctrl.yaml and node.yaml) to turn provisioned VMs into a fully functional cluster. ctrl.yaml initializes the control plane with kubeadm, exports to both the vagrant user and shared folder for host access, installs Flannel CNI with --iface=eth1 configuration, installs Helm, and generates the join command for worker nodes. The node.yaml handles worker node joining by reading the join command from the shared folder and executing it. Both playbooks include idempotency checks to prevent re-initialization on subsequent runs. Also fixed the /etc/hosts file to match the NUM_WORKERS=2 configuration.

Operation commits: 47c7047, 88ff629, 53aa373

### Brewen

Owned the Person D scope: authored `finalization.yml` plus the manifests under `ansible/files/k8s/*` to install and configure MetalLB (pool 192.168.56.90–99), deploy the Nginx ingress controller with a fixed LoadBalancer IP, install the Kubernetes Dashboard with admin RBAC + HTTPS ingress, and provision Istio 1.25.2 with a pinned gateway address. Added readiness waits, local staging of all YAML assets, and host instructions in `K8S_SETUP.md`/`README.md` so running `ansible-playbook finalization.yml` from the host consistently finishes the cluster with ingress, dashboard, and mesh support.

Only commits were made: 53b9397, 919aab3

---

## Week 4 A3

### Cristian

Implemented Kubernetes migration from Docker Compose and Grafana monitoring dashboards. Created Kubernetes manifests with Deployments, Services, Ingress, ConfigMaps, and Secrets. Added shared VirtualBox folder support via hostPath volumes mounted at /mnt/shared for model persistence. Created two comprehensive Grafana dashboards: application metrics dashboard with Gauge, Counter, and Histogram visualizations using rate and histogram_quantile functions, and A/B testing decision support dashboard with version comparisons, template variables, and deployment annotations. Implemented ConfigMap for automatic dashboard import into Grafana.

Operation commits: e3e215b
PR: https://github.com/doda25-team23/operation/pull/4

### Ocean

Helm Chart part.

PR:
https://github.com/doda25-team23/operation/pull/6

### Radu

Monitoring part -> For monitoring, we exposed metrics from both the frontend (Spring Boot Actuator) and the model-service (custom /metrics endpoint). We installed the kube-prometheus-stack Helm chart in the monitoring namespace, which deploys Prometheus, Grafana, and the required CRDs. Our application’s Kubernetes Services were annotated so Prometheus automatically discovers and scrapes them. Grafana was accessed through port-forwarding, where we verified that the frontend and model-service metrics were available for dashboard visualisation.

PRs:
https://github.com/doda25-team23/model-service/pull/4
https://github.com/doda25-team23/app/pull/1
https://github.com/doda25-team23/operation/pull/7
