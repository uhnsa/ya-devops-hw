terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
  service_account_key_file = "../../authorized_key.json"
  folder_id = "b1gnpffe0o8splkcu65v"
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

variable "vm_names" {
    type = list(string)
    default = ["app-node-1", "app-node-2"]
}

resource "yandex_compute_instance" "template-node" {
  count = length(var.vm_names)
  name = element(var.vm_names, count.index)
  hostname = element(var.vm_names, count.index)

  platform_id = "standard-v2"

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    nat = true
  }

  boot_disk {
    initialize_params {
    #   type = "network-hdd"
      size = "40"
      image_id = "fd8un8f40qgmlenpa0qb" # ubuntu 22.04
    }
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

  connection {
    type        = "ssh"
    user        = "devops"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].nat_ip_address
  }

  # copy application
  provisioner "file" {
    source      = "../bingo"
    destination = "/home/devops/bingo"
  }

  # copy config
  provisioner "file" {
    source      = "../config.yaml"
    destination = "/home/devops/config.yaml"
  }

  # copy nginx config site
  provisioner "file" {
    source      = "../nginx-default"
    destination = "/home/devops/nginx-default"
  }

  # copy nginx config
  provisioner "file" {
    source      = "../nginx.conf"
    destination = "/home/devops/nginx.conf"
  }

  # copy service bingo
  provisioner "file" {
    source      = "../bingo.service"
    destination = "/home/devops/bingo.service"
  }

  # copy check health service bingo
  provisioner "file" {
    source      = "../check-health.service"
    destination = "/home/devops/check-health.service"
  }

  # copy check health script
  provisioner "file" {
    source      = "../check-health.sh"
    destination = "/home/devops/check-health.sh"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x bingo",
        "chmod +x check-health.sh",
        "sudo apt update && sudo apt install nginx -y",
        "sudo mkdir /opt/bingo && sudo chown devops:devops /opt/bingo/",
        "sudo mkdir -p /opt/bongo/logs/1fd892b4a8 && sudo chown -R devops:devops /opt/bongo/",
        "mv ./config.yaml /opt/bingo/config.yaml",
        "sudo mv ./nginx-default /etc/nginx/sites-available/default",
        "sudo mv ./nginx.conf /etc/nginx/nginx.conf",
        "sudo mkdir /var/lib/nginx/proxy_cache",
        "sudo chown www-data:root /var/lib/nginx/proxy_cache",
        "sudo systemctl restart nginx",
        "sudo mv /home/devops/bingo.service /etc/systemd/system/",
        "sudo mv /home/devops/check-health.service /etc/systemd/system/",
        "sudo systemctl daemon-reload",
        "sudo systemctl enable bingo",
        "sudo systemctl enable check-health",
        "sleep 480",
        # "sudo systemctl restart bingo",
        # "sleep 120",
        "sudo systemctl restart check-health"
    ]
  }

}

resource "yandex_compute_instance" "postgres-db" {
  name = "postgres-db"
  hostname = "postgres-db"

  platform_id = "standard-v2"

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores         = 4
    memory        = 2
    core_fraction = 5
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    nat = true
  }

  boot_disk {
    initialize_params {
    #   type = "network-hdd"
      size = "40"
      image_id = "fd8un8f40qgmlenpa0qb" # ubuntu 22.04
    }
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

  connection {
    type        = "ssh"
    user        = "devops"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "../bingo"
    destination = "/home/devops/bingo"
  }

  provisioner "file" {
    source      = "../config.yaml"
    destination = "/home/devops/config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
        "sudo apt update && sudo apt install postgresql -y",
        "chmod +x bingo",
        "sudo mkdir /opt/bingo && sudo chown devops:devops /opt/bingo/",
        "mv ./config.yaml /opt/bingo/",
        "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'postgres'\"",
        # "sudo bash -c 'echo \"listen_addresses = '*'\" >> /etc/postgresql/*/main/postgresql.conf'",
        "echo \"listen_addresses = '*'\" | sudo bash -c 'cat >> /etc/postgresql/*/main/postgresql.conf'",
        "sudo bash -c 'echo \"host    all             postgres         10.5.0.0/24            md5\" >> /etc/postgresql/*/main/pg_hba.conf'",
        "sudo systemctl restart postgresql.service",
        "./bingo prepare_db > /dev/null"
    ]
  }
}

resource "yandex_lb_target_group" "load-group" {
  name      = "node-group"
#   region_id = "ru-central1"

  target {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    address   = "${yandex_compute_instance.template-node[0].network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.foo.id}"
    address   = "${yandex_compute_instance.template-node[1].network_interface.0.ip_address}"
  }
}

resource "yandex_lb_network_load_balancer" "load_balance_node" {
  name = "bingo-bongo-nodes"

  listener {
    name        = "bingo-listener"
    port        = 80
    target_port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.load-group.id

    healthcheck {
      name = "http"
      http_options {
        port = 4925
        path = "/ping"
      }
    }
  }
}