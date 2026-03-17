# Terraform Layout

- `aws/`: deployable AWS root for the mainnet production stack.
- `gcp/`: aligned module contract for equivalent GCP deployment inputs and outputs.
- `azure/`: aligned module contract for equivalent Azure deployment inputs and outputs.
- `modules/aws-mainnet/`: provider-specific AWS implementation used by the deploy scripts.
- `modules/gcp-mainnet/` and `modules/azure-mainnet/`: provider-aligned module contracts for future parity work.

The scripts in `infrastructure/scripts/` target the AWS root today.
