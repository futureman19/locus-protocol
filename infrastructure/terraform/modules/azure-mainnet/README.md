# Azure Mainnet Module

Aligned module contract for an Azure implementation of the Locus mainnet stack.

Intended mapping:

- Virtual network with application and database subnets
- PostgreSQL Flexible Server primary + replica
- AKS for indexer and ghost runtime
- VM scale set for Elixir nodes
- Key Vault for runtime secrets
- Application Gateway and internal load balancing

The AWS implementation is the deployable reference in this repository. This module keeps the input/output contract ready for equivalent provider work.
