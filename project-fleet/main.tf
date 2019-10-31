# Variable definitions
#variable "vsphere_user" {}
#variable "vsphere_password" {}
#variable "vsphere_server" {}

# Define the number of resouces to be deployed
variable "source_vm" {
  default = "Windows 2019 Std 100GB"
}
# Define a prefix for the VM name and guest hostname
variable "name_prefix" {
  default = "FTVXDC"
}
# Define the number of resouces to be deployed
variable "new-vms" {
  default = 2
}
# Use an offset to start counting from a certain number
# or else the first server will be named server-01 and receive an ip address 192.168.105.51
variable "offset" {
  default = 1
}
# Start number in last octect of ipv4 address
variable "start_ipv4_address" {
  default = 190
}

# Initialize vSphere provider, variables can be assigned with the var-file terraform parameter
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "VxRail-Datacenter"
}

data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "VxRail-Datacenter"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "VxRail-VSAN-Cluster-01"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "LAN"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.source_vm}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "vm" {
  count = "${var.new-vms}"
  # Define VM name using the resource count +1 making the first name server-01
  # except when an offset is used. If for example offset=1 the first name is server-02
  name             = "${var.name_prefix}${format("%02d", count.index + 1 + var.offset)}"
  resource_pool_id = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  # Changed from example; datastore cluster instead of datastore
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"

  num_cpus = 2
  memory   = 2048
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      windows_options {
        # Define hostname using the resource count +1 making the first name server-01
        # except when an offset is used. If for example offset=1 the first name is server-02
        computer_name = "${var.name_prefix}${format("%02d", count.index + 1 + var.offset)}"
        workgroup    = "fleet-tutors.co.uk"
        admin_password = "Master2010"
      }

      network_interface {
        ipv4_address = "${format("172.16.20.%d", (count.index + 1 + var.offset + var.start_ipv4_address))}"
        ipv4_netmask = 23
      }

      ipv4_gateway = "172.16.20.1"
    }
  }
}