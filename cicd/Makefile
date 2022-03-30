all: clean init workspace format plan apply

# ----------------------------
# 1.- Creation bucket process
# ----------------------------

init:
	cd infra && \
	terraform init

workspace:
	cd infra && \
	[[ $$(terraform workspace list | grep dev | wc -l) -eq 0 ]] && \
	terraform workspace new dev || \
	terraform workspace select dev

format:
	cd infra && \
	terraform fmt -check || \
	echo "Revisa el formato de los ficheros terraform"

plan: 
	cd infra && \
	terraform plan -var-file="dev.tfvars"

apply:
	cd infra && \
	terraform apply -var-file="dev.tfvars" -auto-approve

# ----------------------------
# 2.- Cleaning bucket process
# ----------------------------

# Clean DEV environment
clean: remove-objects remove-ws

# Removes objects in DEV S3 bucket, if it exists
remove-objects:
	@echo "Borrando objetos del bucket kc-acme-storage-dev..." && \
	[[ $$(aws s3 ls s3://kc-acme-storage-dev 2>&1 | grep "NoSuchBucket" | wc -l) -eq 0 ]] && \
    aws s3 rm s3://kc-acme-storage-dev --recursive  || \
    echo "No existe el bucket" 
	
# Removes DEV bucket and workspace, if workspace exists
remove-ws:
	@cd infra && \
	[[ $$(terraform workspace list | grep dev | wc -w) -gt 0 ]] && \
	terraform workspace select dev && \
	terraform destroy -var-file="dev.tfvars" -auto-approve && \
	terraform workspace select default && \
	terraform workspace delete dev || \
	echo "No existe el workspace dev. No se puede eliminar."
