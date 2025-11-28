# Kubernetes Cluster Setup

This directory contains the infrastructure-as-code for provisioning a Kubernetes cluster using Vagrant and Ansible.

## Prerequisites

- Vagrant
- VirtualBox
- **No Ansible installation required!** (Ansible automatically installs inside VMs using `ansible_local`)

## Quick Start

```bash
# Start the cluster
vagrant up

# Check status
vagrant status

# SSH into controller
vagrant ssh ctrl

# SSH into a worker node
vagrant ssh node-1

# Destroy the cluster
vagrant destroy -f
```

## Configuration

Edit the variables at the top of `Vagrantfile` to customize:

- `NUM_WORKERS`: Number of worker nodes (default: 2)
- `CTRL_CPUS`: Controller CPU cores (default: 1)
- `CTRL_MEMORY`: Controller memory in MB (default: 4096)
- `WORKER_CPUS`: Worker CPU cores (default: 2)
- `WORKER_MEMORY`: Worker memory in MB (default: 6144)

## Network Configuration

- **Controller**: 192.168.56.100
- **Worker 1**: 192.168.56.101
- **Worker 2**: 192.168.56.102
- **Additional workers**: 192.168.56.103+

## Cluster Components

After provisioning, the cluster will include:
- Kubernetes 1.32.4
- Flannel CNI for pod networking
- MetalLB for LoadBalancer services
- Nginx Ingress Controller
- Kubernetes Dashboard
- Istio service mesh

## Next Steps

1. Test basic provisioning: `vagrant up`
2. Add SSH key registration (Step 4)
3. Implement remaining setup steps in Ansible playbooks
