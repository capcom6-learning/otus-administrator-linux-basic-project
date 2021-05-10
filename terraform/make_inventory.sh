#!/bin/bash

# Попытка сформировать файл инветаря для Ansible из состояния Terraform

cat terraform.tfstate | jq ".resources[].instances[].attributes as {ip_address: \$ip_address, tags: \$tags} | {ip: \$ip_address, tags: \$tags} | {ip, tags: .tags[]}"