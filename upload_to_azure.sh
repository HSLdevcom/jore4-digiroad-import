#!/usr/bin/env bash

# Login to Azure
az login
az account set --subscription "jore4"

# Upload all sql files to blob storage
time az storage azcopy blob upload \
  --source "./workdir/pgdump/*.sql" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"

# Upload all json files to blob storage
time az storage azcopy blob upload \
  --source "./workdir/pgdump/*.json" \
  --recursive \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --container "jore4-digiroad"  

# List all sql files in blob storage
az storage blob list \
  --container-name "jore4-digiroad" \
  --account-name "jore4storage" \
  --auth-mode "login" \
  --query "[].name"
