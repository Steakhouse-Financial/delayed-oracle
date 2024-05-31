## Delayed Oracle

The DelayedOracle smart contract provide an ERC4626 interface for Morpho oracle factory V2 to access an underlying price but with a delay (returning an new updated price only after a configurable time lag). The oracle relies on permissionless third parties to call update() from times to times to update the underlying price.

For the DelayedERC4626OracleMorphoIntegration test, you need to add a ETH_RPC_URL environment variable (in a .env file for instance).