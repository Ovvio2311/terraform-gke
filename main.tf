
data "google_client_config" "default" {  
}
/*data "google_client_config" "update" {
  depends_on = [module.gke]
}*/

data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "us-central1-c"
  depends_on = [module.gke]
}
# =========================================================================================================
# =========================================================================================================
# =========================================================================================================
provider "google" {
  # credentials = file("/home/alan1031/proven-fort-421209-46f0cd0f5c41.json")
  project = var.project_id
  region  = "us-central1"
  zone    = "us-central1-c"
}


# =========================================================================================================
# =========================================================================================================
# =========================================================================================================

module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  depends_on   = [module.gke]
  project_id   = var.project_id  
  location     = module.gke.location
  cluster_name = module.gke.name
  
  
}
resource "local_file" "config" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "kubeconfig"
  depends_on = [module.gke_auth]
}


module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = ">= 7.5"

  project_id   = var.project_id
  network_name = var.network

  subnets = [
    {
      subnet_name           = var.subnetwork
      subnet_ip             = "10.0.0.0/24"
      subnet_region         = var.region
      subnet_private_access = "false"
    },
  ]

  secondary_ranges = {
    (var.subnetwork) = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "172.20.0.0/20"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "172.18.0.0/18"
      },
    ]
  }
}

data "google_compute_subnetwork" "subnetwork" {
  name       = var.subnetwork
  project    = var.project_id
  region     = var.region
  depends_on = [module.gcp-network]
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 30.0"
  service_account= "default"  
  project_id = var.project_id
  name       = var.cluster_name
  regional   = false
  region     = var.region
  zones      = slice(var.zones, 0, 1)
  
  network                 = module.gcp-network.network_name
  subnetwork              = module.gcp-network.subnets_names[0]
  ip_range_pods           = var.ip_range_pods_name
  ip_range_services       = var.ip_range_services_name
  
  create_service_account  = false
  http_load_balancing     = false
  enable_private_endpoint = false
  enable_private_nodes    = false
  master_ipv4_cidr_block  = "10.0.0.0/24"
  deletion_protection     = false
  remove_default_node_pool= true
  network_policy          = false
  horizontal_pod_autoscaling = false
  kubernetes_version      = "1.29"
  release_channel         = "UNSPECIFIED"
  fleet_project           = var.project_id
  disable_legacy_metadata_endpoints = true
  
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/24"
      display_name = "VPC"
    },
  ]

  node_pools = [
    {
      name               = "fyp-node-pool"
      machine_type       = "e2-medium"
      image_type         = "UBUNTU_CONTAINERD"
      node_version       = "1.29"
      min_count          = 1
      max_count          = 1
      disk_size_gb       = 100
      disk_type          = "pd-balanced"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      initial_node_count = 1
      # service_account = google_service_account.default.email
      
    },
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/servicecontrol",
    ]

    fyp-node-pool = [
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/servicecontrol",
    ]
  }
  

  node_pools_labels = {

    all = {

    }
    my-node-pool = {

    }
  }

  node_pools_metadata = {
    all = {}

    my-node-pool = {}

  }

  node_pools_tags = {
    all = []

    my-node-pool = []

  }
}
module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project_id
  network_name = var.network
  depends_on = [module.gcp-network]
  rules = [
    {
      name                    = "allow-ingress"
      description             = null
      direction               = "INGRESS"
      priority                = null
      destination_ranges      = ["0.0.0.0/0"]
      source_ranges           = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [{
        protocol = "tcp"
        ports    = ["22","5050","3389","30443","2224","9443","8443","31080","31443","32080","32443","32100"]
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "allow-http"
      description             = null
      direction               = "INGRESS"
      priority                = null
      destination_ranges      = ["0.0.0.0/0"]
      source_ranges           = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [{
      protocol = "tcp"
      ports    = ["80","443"]
    }]
  }]
}
/*
resource "google_compute_router" "router" {
  name    = "fyp-router"
  region  = data.google_compute_subnetwork.subnetwork.region
  network = var.network
  depends_on = [module.gcp-network]
  bgp {
    asn = 64514
  }
}
resource "google_compute_router_nat" "nat" {
  name                               = "fyp-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  depends_on                         = [google_compute_router.router]
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
*/
# =========================================================
resource "google_artifact_registry_repository" "my-repo" {
  location      = "us-central1"
  repository_id = var.project_id
  description   = "standard docker repository"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  # remote_repository_config {
  #  description = "docker hub"
   # docker_repository {
    #  public_repository = "DOCKER_HUB"
   # }
  # }
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-prerelease"
    action = "DELETE"
    condition {
      tag_state    = "UNTAGGED"
      # tag_prefixes = ["alpha", "v0"]
      older_than   = "259200s"
    }
  }
  
}
# kms
# ===================================================

resource "google_kms_key_ring" "keyring" {
  name     = "fyp-portal-key"
  location = "us-central1"
}
resource "google_kms_crypto_key" "fyp-key" {
  name            = "fyp-crypto-key"
  key_ring        = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"
  # rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "kms_account" {
  account_id   = "fyp-access-gcp-role"
  display_name = "kms-access"
  create_ignore_already_exists = true
}
resource "google_kms_key_ring_iam_binding" "key_ring" {
  key_ring_id = google_kms_key_ring.keyring.id
  role        = "roles/cloudkms.admin"
  depends_on = [google_service_account.kms_account]
  members = [
    "serviceAccount:${google_service_account.kms_account.email}"
  ]
}
resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.fyp-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  depends_on = [google_service_account.kms_account]

  members = [
    "serviceAccount:${google_service_account.kms_account.email}"
  ]
}

# binding to IAM 
resource "google_project_iam_binding" "kmsbindiam" {
  project = var.project_id
  depends_on = [google_service_account.bucket_account]
  role    = "roles/cloudkms.admin"
  members = [
    "serviceAccount:${google_service_account.kms_account.email}"
  ]
}

# ======================================================================

# create bucket
resource "google_storage_bucket" "static" {
  name          = "fyp-bucket-gym2024m"
  location      = "us-central1"
  force_destroy = true
  storage_class = "COLDLINE"

  uniform_bucket_level_access = true

  
}
# create bucket service account
resource "google_service_account" "bucket_account" {
  account_id   = "fyp-bucket-access-role"
  display_name = "bucket-access"
  create_ignore_already_exists = true
  
}
# binding to IAM 
resource "google_project_iam_binding" "binding" {
  project = var.project_id
  depends_on = [google_service_account.bucket_account]
  role    = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.bucket_account.email}"
  ]
}
# binding to bucket
resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.static.name
  depends_on = [google_service_account.bucket_account]
  role     = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.bucket_account.email}"
  ]
}
# binding to bucket
resource "google_storage_bucket_iam_binding" "storage" {
  bucket = google_storage_bucket.static.name
  depends_on = [google_service_account.bucket_account]
  role     = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.bucket_account.email}"
  ]
}
# binding storage admin to user 
resource "google_project_iam_binding" "binding" {
  project = var.project_id
  depends_on = [google_service_account.bucket_account]
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.bucket_account.email}"
  ]
}

# ============================================================
# create ai service account
resource "google_service_account" "ai_account" {
  account_id   = "fyp-ai-access"
  display_name = "fyp-ai-access"
  create_ignore_already_exists = true  
}
# binding to IAM 
resource "google_project_iam_binding" "binding_ai" {
  project = var.project_id
  depends_on = [google_service_account.ai_account]
  role    = "roles/aiplatform.admin"
  members = [
    "serviceAccount:${google_service_account.ai_account.email}"
  ]
}
