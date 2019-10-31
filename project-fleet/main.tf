################################################################################ DEFINE VARIABLES ################################################################################
# Template to be used
variable "source_vm" {
  default = "Windows 2019 Std 100GB"
}
# Name of the VM or VMs
variable "name_prefix" {
  default = "SEVXSQL"
}
# How many - consecutive - VM-s to deploy (1 or more)
variable "new-vms" {
  default = 1
}
# Use an offset to start counting from a certain number
# or else the first server will be named server-01 and receive an ip address 172.16.20.x- or what ever starting value you define in the next two variable
variable "offset" {
  default = 0
}
# Start number in last octect of ipv4 address
variable "start_ipv4_address" {
  default = 190
}

#################################################################### SYSTEM PARAMETERS - no need to chagne ####################################################################

# Initialize vSphere provider, variables can be assigned with the var-file terraform parameter
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert. accept it
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "VxRail-Datacenter"
}

## commented out, as we do not have cluster - instead we use datastores - EFS
#data "vsphere_datastore_cluster" "datastore_cluster" {
#  name          = "VxRail-Datacenter"
#  datacenter_id = "${data.vsphere_datacenter.dc.id}"
#}

#changed back to datastore -EFS
data "vsphere_datastore" "datastore" {
  name          = "VxRail-VSAN-Datastore-01"
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

  /*
  #commented out, as we do not have cluster - instead we use datastores - EFS
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  */

  ## changed back to datastore - EFS
  datastore_id = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2 # default setting, can be adjusted / perhaps added to a variable latter
  memory   = 2048 # default setting, can be adjusted / perhaps added to a variable latter
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
        /*
        Define hostname using the resource count +1 making the first name server-01
        except when an offset is used. If for example offset=1 the first name is server-02
        */
        computer_name = "${var.name_prefix}${format("%02d", count.index + 1 + var.offset)}"
        workgroup    = "supportingeducation.com" # default setting, can be adjusted / perhaps added to a variable latter
        admin_password = "Yln0l4c0l" # default setting, can be adjusted / perhaps added to a variable latter
      }

      network_interface {
        ipv4_address = "${format("172.16.20.%d", (count.index + 1 + var.offset + var.start_ipv4_address))}"
        ipv4_netmask = 23
      }

      ipv4_gateway = "172.16.20.1"
    }
  }
}