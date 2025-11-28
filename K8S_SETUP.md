# Kubernetes Cluster Setup

This guide explains how to bring up the Vagrant-based Kubernetes lab environment, run the post-provisioning playbook (Person D scope), and access the cluster services.

## Prerequisites

- VirtualBox 7.x with host-only networking enabled
- Vagrant 2.4+
- Ansible 2.16+ on the host (only needed for `finalization.yml`)
- 24 GB free RAM is recommended (4 GB ctrl + 2×6 GB workers + host overhead)

## Provisioning Workflow

1. **Boot the VMs**

   ```bash
   vagrant up
   ```

   This creates the controller (`ctrl`) and worker nodes (`node-1`, `node-2`) with the networking, SSH keys, container runtime, kubeadm, etc. already configured.

2. **Run the finalization playbook (once the nodes are `Ready`)**

   ```bash
   # Allow Ansible to SSH via the generated Vagrant key
   export CTRL_KEY=$(vagrant ssh-config ctrl | awk '/IdentityFile/ {print $2}')

   ansible-playbook \
     -i 192.168.56.100, \
     -u vagrant \
     --private-key "${CTRL_KEY}" \
     --ssh-extra-args="-o StrictHostKeyChecking=no" \
     finalization.yml
   ```

   The trailing comma in the inventory tells Ansible to treat the single IP as an inventory list. Re-running the playbook is safe and will reconcile add-ons if something drifted.

3. **Fetch kubeconfig (already exported by `ctrl.yml`)**

   ```bash
   export KUBECONFIG=$PWD/kubeconfig/config
   kubectl get nodes
   ```

4. **Tear down the cluster when finished**
   ```bash
   vagrant destroy -f
   ```

## Configurable Resources

Edit the variables at the top of `Vagrantfile` to tune resources:

| Variable                       | Purpose                | Default     |
| ------------------------------ | ---------------------- | ----------- |
| `NUM_WORKERS`                  | Number of worker nodes | `2`         |
| `CTRL_CPUS`, `CTRL_MEMORY`     | Controller vCPU / RAM  | `1`, `4096` |
| `WORKER_CPUS`, `WORKER_MEMORY` | Worker vCPU / RAM      | `2`, `6144` |

## Network Plan

| Host         | IP                            | Notes                     |
| ------------ | ----------------------------- | ------------------------- |
| ctrl         | `192.168.56.100`              | Control-plane endpoint    |
| node-1       | `192.168.56.101`              | Worker                    |
| node-2       | `192.168.56.102`              | Worker                    |
| MetalLB pool | `192.168.56.90-192.168.56.99` | Ingress / Istio addresses |

Private IPs are reachable directly from the host (VirtualBox host-only network). No port forwards are required.

## What finalization’s Playbook Installs

Running `finalization.yml` performs the following idempotent steps on the controller node:

- Installs MetalLB (v0.14.9) and configures the `primary-pool` address range (`192.168.56.90-99`) plus the matching `L2Advertisement`.
- Deploys the Nginx Ingress Controller via Helm with a fixed LoadBalancer IP (`192.168.56.90`) and default ingress class `nginx`.
- Installs the Kubernetes Dashboard via Helm, provisions an `admin-user` ServiceAccount/ClusterRoleBinding, and exposes it through an HTTPS-aware ingress on `dashboard.local`.
- Downloads Istio 1.25.2, makes `istioctl` available globally, applies the provided `IstioOperator` manifest, and assigns the Istio ingress gateway a fixed IP (`192.168.56.91`).
- Adds wait conditions so that dependent steps do not race (e.g., waits for MetalLB, Nginx, istiod, and the Istio ingress gateway pods to become Ready).

## Accessing Cluster Services

After the playbook finishes, add the ingress endpoints to your host `/etc/hosts` (or OS equivalent):

```
192.168.56.90 dashboard.local
```

More hostnames can be appended later when you deploy your own workloads through the Nginx ingress.

- **Dashboard**: `https://dashboard.local/` (retrieve login token with `kubectl -n kubernetes-dashboard create token admin-user` from the controller)
- **Ingress controller status**: `kubectl get svc -n ingress-nginx`
- **MetalLB allocation**: `kubectl get ipaddresspools.metallb.io -A`
- **Istio ingress gateway**: `kubectl get svc istio-ingressgateway -n istio-system`

## Troubleshooting Tips

- `kubectl get nodes` should show `ctrl`, `node-1`, and `node-2` all in `Ready` state before running `finalization.yml`.
- Use `ANSIBLE_STDOUT_CALLBACK=debug` when running the playbook if you need more insight.
- If MetalLB fails to assign IPs, ensure no other VirtualBox host-only network overlaps with `192.168.56.0/24`.
- Re-run `finalization.yml` any time you tweak the manifests in `ansible/files/k8s/*`; the tasks are idempotent and will reconcile the changes.
