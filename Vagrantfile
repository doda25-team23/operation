# Configuration variables
NUM_WORKERS = 2
CTRL_CPUS = 2
CTRL_MEMORY = 4096
WORKER_CPUS = 2
WORKER_MEMORY = 6144
BASE_IP = "192.168.56"
CTRL_IP = "#{BASE_IP}.100"

Vagrant.configure("2") do |config|
  # Base box for all VMs
  config.vm.box = "bento/ubuntu-24.04"

  # Controller node
  config.vm.define "ctrl" do |ctrl|
    ctrl.vm.hostname = "ctrl"
    ctrl.vm.network "private_network", ip: CTRL_IP

    # Shared folder for exporting kubeconfig to host
    ctrl.vm.synced_folder ".", "/vagrant", type: "virtualbox"

    ctrl.vm.provider "virtualbox" do |vb|
      vb.name = "k8s-ctrl"
      vb.cpus = CTRL_CPUS
      vb.memory = CTRL_MEMORY
    end

    # Provision controller with Ansible (runs inside VM)
    ctrl.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "general.yaml"
      ansible.groups = {
        "ctrl" => ["ctrl"],
        "all:vars" => {
          "num_workers" => NUM_WORKERS
        }
      }
      ansible.install_mode = "default"
      ansible.provisioning_path = "/vagrant"
    end

    ctrl.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ctrl.yaml"
      ansible.groups = {
        "ctrl" => ["ctrl"]
      }
      ansible.provisioning_path = "/vagrant"
    end
  end

  # Worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.hostname = "node-#{i}"
      node.vm.network "private_network", ip: "#{BASE_IP}.#{100 + i}"

      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-node-#{i}"
        vb.cpus = WORKER_CPUS
        vb.memory = WORKER_MEMORY
      end

      # Provision worker nodes with Ansible (runs inside VM)
      node.vm.provision "ansible_local" do |ansible|
        ansible.playbook = "general.yaml"
        ansible.groups = {
          "nodes" => ["node-[1:#{NUM_WORKERS}]"],
          "all:vars" => {
            "num_workers" => NUM_WORKERS
          }
        }
        ansible.install_mode = "default"
        ansible.provisioning_path = "/vagrant"
      end

      node.vm.provision "ansible_local" do |ansible|
        ansible.playbook = "node.yaml"
        ansible.groups = {
          "nodes" => ["node-[1:#{NUM_WORKERS}]"]
        }
        ansible.provisioning_path = "/vagrant"
      end
    end
  end
end
