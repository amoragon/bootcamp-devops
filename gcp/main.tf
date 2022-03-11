terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.7.0"
    }
  }
}

provider "google" {
  credentials = file("cred.json")
  project     = "keepcoding-gcp-practicas"
  region      = "europe-west3"
  zone        = "europe-west3-a"
}

resource "google_compute_network" "keepcoding-vpc-network" {
  name = "keepcoding-vpc-network"
}

resource "google_storage_bucket" "keepcoding_terraform_bonus_bucket" {
  name          = "keepcoding_terraform_bonus_bucket"
  location      = "EUROPE-WEST3"
  force_destroy = true
  storage_class = "STANDARD"

  versioning {
    enabled = false
  }
}

resource "google_compute_instance" "keepcoding-terraform-bonus-instance" {
  name = "keepcoding-terraform-bonus-instance"
  machine_type = "f1-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network = google_compute_network.keepcoding-vpc-network.name

    access_config {
    }
  }
}
