packer {
  required_plugins {
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "SSH_PRIVATE_KEY_FILE" {
  type    = string
  default = ""
}

variable "SSH_PUB_KEY" {
  type    = string
  default = ""
}

local "date" {
  expression = "${formatdate("YYYY-MM-DD", timestamp())}"
}

source "qemu" "ubuntu_20_04" {
  boot_command              = [
    "<enter><enter><f6><esc><wait>",
    "<bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs>",
    "<bs><bs><bs><bs><bs><bs><bs><bs>",
    "/casper/vmlinuz ",
    "initrd=/casper/initrd ",
    " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
    " PACKER_USER=ubuntu PACKER_AUTHORIZED_KEY={{ `${var.SSH_PUB_KEY}` | urlquery }}",
    "<wait><enter>"
  ]
  boot_wait                 = "3s"
  disk_size                 = 8000
  format                    = "qcow2"
  headless                  = true
  http_directory            = "httpdir"
  http_port_max             = 8550
  http_port_min             = 8500
  iso_checksum              = "sha256:b8f31413336b9393ad5d8ef0282717b2ab19f007df2e9ed5196c13d8f9153c8b"
  iso_url                   = "https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso"
  memory                    = 1024
  qemuargs                  = [["-cpu", "host"]]
  shutdown_command          = "sudo -- sh -c 'rm /etc/sudoers.d/99-egi-installation && shutdown -h now'"
  ssh_clear_authorized_keys = true
  ssh_private_key_file      = "${var.SSH_PRIVATE_KEY_FILE}"
  ssh_timeout               = "20m"
  ssh_username              = "ubuntu"
  vm_name                   = "Ubuntu.20.04-${local.date}"
}

build {
  sources = ["source.qemu.ubuntu_20_04"]

  provisioner "ansible" {
    playbook_file = "provisioners/init.yaml"
    use_proxy     = false
    user          = "ubuntu"
  }

  provisioner "ansible" {
    pause_before  = "30s"
    playbook_file = "provisioners/base.yaml"
    use_proxy     = false
    user          = "ubuntu"
  }

  provisioner "shell" {
    script = "provisioners/cleanup.sh"
  }

  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
    custom_data = {
      "org.openstack.glance.os_distro" = "ubuntu"
      "org.openstack.glance.os_version" = "20.04"
      "org.openstack.glance.os_type" = "linux"
      "org.openstack.glance.architecture" = "x86_64"
      "eu.egi.cloud.description" = "EGI Ubuntu 20.04 image"
    }
  }

}
