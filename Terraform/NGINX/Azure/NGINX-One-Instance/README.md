# NGINXOne-Instance
# Your Project

### You need the NGINX One Licensing artifaces and rename them to match the following.
- nginx-repo.crt
- nginx-repo.key
- nginx-repo.jwt
  

### Change terraform.tfvars.boilerplate file and rename to terraform.tfvars

### Get a new NGINX One Dataplane token and place it in the terraform.tfvars file
- This needs to be done from the NGINX One Console.
- Maybe I can add automation to automatically generate an NGINX One Data Plane token.


### Notes:
- jwt-validation.tf will read the f5_sat from the nginx-repo.jwt
- f5_sat is the expiration date of the JWT
