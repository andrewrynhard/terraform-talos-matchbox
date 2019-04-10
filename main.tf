locals {
  talos_platform = "talos.platform=packet"
}

data "template_file" "matchbox_talos_group" {
  template = "${file("${path.module}/templates/matchbox_default_group.tmpl")}"
}

data "template_file" "matchbox_talos_profile" {
  template = "${file("${path.module}/templates/matchbox_profile.tmpl")}"

  vars {
    version = "${var.talos_version}"
    args    = "${jsonencode(concat(var.boot_args, list(local.talos_platform, "talos.userdata=none")))}"
  }
}

resource "null_resource" "matchbox_profiles" {
  triggers {
    talos = "${data.template_file.matchbox_talos_profile.rendered}"
    ipxe  = "${packet_device.ipxe.id}"
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${packet_device.ipxe.network.0.address}"
    timeout     = "2m"
    agent       = true
  }

  provisioner "remote-exec" {
    inline = [
      "cd /var/lib/matchbox/assets/talos/${var.talos_version}",
      "wget https://github.com/autonomy/talos/releases/download/${var.talos_version}/vmlinuz -O vmlinuz",
      "wget https://github.com/autonomy/talos/releases/download/${var.talos_version}/initramfs.xz -O initramfs.xz",
      "wget https://github.com/autonomy/talos/releases/download/${var.talos_version}/rootfs.tar.gz -O rootfs.tar.gz",
    ]
  }

  provisioner "file" {
    content     = "${data.template_file.matchbox_talos_group.rendered}"
    destination = "/var/lib/matchbox/groups/talos.json"
  }

  provisioner "file" {
    content     = "${data.template_file.matchbox_talos_profile.rendered}"
    destination = "/var/lib/matchbox/profiles/talos.json"
  }
}

resource "packet_device" "ipxe" {
  hostname         = "${format("ipxe-%d", count.index + 1)}"
  operating_system = "ubuntu_18_04"
  plan             = "t1.small.x86"
  facilities       = ["${var.packet_facility}"]
  project_id       = "${var.project_id}"
  billing_cycle    = "hourly"

  connection {
    type        = "ssh"
    user        = "root"
    host        = "${packet_device.ipxe.network.0.address}"
    private_key = "${file("/root/.ssh/id_rsa")}"
    timeout     = "2m"
    agent       = false
  }

  // Install Matchbox
  provisioner "remote-exec" {
    inline = [
      "wget https://github.com/coreos/matchbox/releases/download/v0.7.1/matchbox-v0.7.1-linux-amd64.tar.gz",
      "tar xzvf matchbox-v0.7.1-linux-amd64.tar.gz",
      "mv matchbox-v0.7.1-linux-amd64/matchbox /usr/local/bin",
      "id matchbox || useradd -U matchbox",
      "mkdir -p /var/lib/matchbox/assets/talos/${var.talos_version}",
      "mkdir -p /var/lib/matchbox/groups",
      "mkdir -p /var/lib/matchbox/profiles",
      "chown -R matchbox:matchbox /var/lib/matchbox",
      "cp matchbox-v0.7.1-linux-amd64/contrib/systemd/matchbox-local.service /etc/systemd/system/matchbox.service",
      "systemctl daemon-reload",
      "systemctl enable matchbox",
      "systemctl start matchbox",
    ]
  }
}
