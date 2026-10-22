# Checks Terraform / IaC (AWS y OCI)

La mayoría de hallazgos IaC caen en A05 (misconfiguration), A02 (secretos/cifrado) y A01 (acceso). Clasifícalos en la categoría OWASP correspondiente en el reporte.

## Secretos (A02) — revisar primero

- Credenciales en `.tf` o `.tfvars` versionados: `password =`, `secret =`, claves de provider hardcodeadas en bloques `provider`.
- `*.tfvars` con secretos fuera de `.gitignore`. Verificar con `git ls-files *.tfvars`.
- **El state guarda secretos en texto plano**: ¿dónde vive el state? Backend remoto (S3/OCI Object Storage) con cifrado y acceso restringido, nunca `terraform.tfstate` en git.
- Outputs que exponen secretos sin `sensitive = true`.
- Fix: variables con `sensitive = true` + valores desde Secrets Manager/OCI Vault o variables de entorno (`TF_VAR_*`), y rotar lo ya expuesto.

## Exposición de red (A01/A05)

**AWS:**
- Security groups con `cidr_blocks = ["0.0.0.0/0"]` en ingress — grave en puertos de gestión/datos (22, 3389, 1521, 3306, 5432, 6379, 27017). En 80/443 de un ALB público es aceptable: contexto manda.
- `aws_db_instance` / RDS con `publicly_accessible = true`.
- Subnets con `map_public_ip_on_launch = true` para workloads que no lo necesitan.

**OCI:**
- `oci_core_security_list` / NSG con `source = "0.0.0.0/0"` en puertos de gestión.
- Instancias con IP pública (`assign_public_ip = true`) que deberían ir tras LB/bastion.

**Grep:** `0\.0\.0\.0/0`, `publicly_accessible\s*=\s*true`, `assign_public_ip\s*=\s*true`.

## Storage (A01/A05)

**S3:** `acl = "public-read"`, ausencia de `aws_s3_bucket_public_access_block`, sin `server_side_encryption_configuration`, sin versioning en buckets críticos.
**OCI Object Storage:** `access_type = "ObjectRead"` o `"AnyObjectRead"` en buckets que no son públicos a propósito.

## Cifrado at-rest (A02)

- RDS/EBS/EFS sin `storage_encrypted = true` / `encrypted = true`.
- OCI: volúmenes y buckets usan cifrado por defecto, pero verificar si exigen Customer-Managed Keys por compliance.
- Logs y snapshots heredan: si la fuente no cifra, nada cifra.

## IAM (A01/A04)

- Policies con `"Action": "*"` + `"Resource": "*"` — wildcard doble es hallazgo siempre; wildcard simple, evaluar contexto.
- Usuarios IAM con access keys donde un rol serviría (instancias, CI/CD → roles/OIDC, no keys de larga vida).
- OCI: policies `manage all-resources in tenancy` para grupos que no son admin.
- `iam:PassRole` sin condición de restricción.

## Metadata / SSRF (A10)

- AWS: instancias sin IMDSv2 exigido. Fix:
  ```hcl
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  ```

## Logging (A09)

- Sin CloudTrail / OCI Audit configurado en el código (o sin validar que exista fuera).
- ALB/S3 access logs desactivados, VPC Flow Logs ausentes en redes productivas.
- Retención de logs sin definir.

## Higiene general (A06/A08)

- Providers y módulos sin pin de versión (`version = "~> x.y"` ausente, módulos de registry sin versión, módulos por git sin ref).
- Imágenes/AMIs por nombre mutable en vez de ID o filtro determinista.
- Recomendar correr `terraform validate` y, si están disponibles, `tfsec`/`checkov`/`trivy config` para complementar el análisis manual.
