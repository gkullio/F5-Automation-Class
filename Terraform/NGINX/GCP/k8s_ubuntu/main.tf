# Generate random suffix for unique naming
resource "random_id" "random_id" {
  byte_length = 2
}
