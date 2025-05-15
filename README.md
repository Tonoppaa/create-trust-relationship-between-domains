# create-trust-relationship-between-domains
This script will create a trust relationship between two domains. The script will:
  - Check & change (if necessary) the target domain IP address
  - Check & change (if necessary) the target domain DNS address
  - Read user credentials from the target domain admin (Notice! You need to create a .txt-file yourself, which includes the correct admin credentials, in order to create a trust relationship between the domains).
  - Check the ADTrust (trust relatioship), if it exists and create it if necessary
  - Create a folder for both domain users
  - Create a SmbShare to the newly created folder for both domain users
  - Set access rights for the newly created folder for both domain users
  - Add an example .txt-file, which both domain users can modify.
