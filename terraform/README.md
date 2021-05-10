## Работа с Terraform

Terraform настроен на работу с облачным провайдером Linode. Перед началом развертывания инфраструктуры необходимо на основании файла `secret.tfvars.template` создать файл `secret.tfvars`, содержащий токены и пароли для доступа. В файле `terraform.tfvars` указать открытый ключ для доступа по SSH.

```bash
terraform init
terraform plan -var-file=secret.tfvars -out=changes.tfplan
terraform apply changes.tfplan
```