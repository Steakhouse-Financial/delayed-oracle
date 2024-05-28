## Delayed Oracle

The DelayedOracle smart contract provide an Chainlink compliant interface to access an underlying oracle but with a delay (returning an new updated price only after a configurable time lag). The oracle relies on permissionless third parties to call update() from times to times to update the underlying price.
