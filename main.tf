resource "google_storage_bucket" "static" {
  name          = "fyp-bucket-4108"
  location      = "us-central1"
  force_destroy = true
  storage_class = "COLDLINE"

  uniform_bucket_level_access = true

  
}
resource "google_service_account" "bucket_account" {
  account_id   = "fyp-bucket-access-role"
  display_name = "bucket-access"
  create_ignore_already_exists = true
  
}
resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.static.name
  role = "roles/storage.admin"
  members = [
    "serviceAccount:fyp-bucket-access-role@my-project-4108m.iam.gserviceaccount.com",
  ]
}
