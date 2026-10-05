# BaseStrategies & TokenizedStrategies

This document has been superseded by comprehensive NatSpec documentation embedded in the core contracts. Please refer to:

- Core implementation and architecture:
  - `src/core/TokenizedStrategy.sol`
  - `src/core/BaseStrategy.sol`
- Strategy variants:
  - `src/strategies/yieldDonating/YieldDonatingTokenizedStrategy.sol`
  - `src/strategies/yieldSkimming/YieldSkimmingTokenizedStrategy.sol`
- Interfaces:
  - `src/core/interfaces/ITokenizedStrategy.sol`
  - `src/core/interfaces/IBaseStrategy.sol`
  - `src/strategies/yieldSkimming/IYieldSkimmingStrategy.sol`
- Periphery:
  - `src/strategies/periphery/BaseHealthCheck.sol`
  - `src/strategies/periphery/BaseYieldSkimmingHealthCheck.sol`
  - `src/strategies/periphery/UniswapV3Swapper.sol`

Rationale: co-locating documentation with code ensures accuracy and reduces drift. The files above contain the vision, threat model boundaries, trust minimization notes, functional requirements mapping, and detailed behavioral specs for each strategy family.


