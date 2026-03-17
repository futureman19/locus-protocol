# GCP Mainnet Module

Aligned module contract for a GCP implementation of the Locus mainnet stack.

Intended mapping:

- VPC + private subnetwork
- Cloud SQL PostgreSQL primary + replica
- GKE cluster for indexer and ghost runtime
- Managed instance group for Elixir nodes
- Secret Manager for runtime secrets
- External and internal load balancers

The AWS implementation is the deployable reference in this repository. This module keeps the input/output contract ready for equivalent provider work.
