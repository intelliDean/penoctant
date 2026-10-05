# Comprehensive Research & Feasibility Report: PEN–Octant Integration Proof

## Executive Summary

Based on a thorough investigation of:
1. The **Shutter Perpetual Endowment Network (PEN)** codebase (`shutter-network/perpetual-endowment-network`), deployment artifacts (`shutter-network/shutter-pen-deployment-artifacts`), and live Ethereum mainnet state;
2. The **Octant v2 Core** contracts (`golemfoundation/octant-v2-core` @ release `1.3.0`), specifically `YieldDonatingTokenizedStrategy`, `MorphoCompounderStrategy`, and `MorphoCompounderStrategyFactory`;
3. The live on-chain contracts on Ethereum Mainnet:
   - PEN PrincipalManager: `0x4517651c7071fecDA97Eb656a9d3A50B92b84517`
   - PEN BondingTranche: `0x652a9A770f9Cfe26e409Aa63E84B8a4e21abe1e5`
   - PEN SeatToken: `0xe2F401A0fb40dA191b9fa8C44Fa09D31cE17374c`
   - PEN Governance Safe: `0xB7f69C3cd9E3dFB4aE0Ed9ee65eb2Ed42EdeECE3`
   - Yearn Strategy USDC / Morpho Compounder: `0x074134A2784F4F66b6ceD6f68849382990Ff3215`
   - Steakhouse USDC Morpho Vault: `0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB`
   - Octant V1 Factory: `0x052d20B0e0b141988bD32772C735085e45F357c1`
   - Octant V1 Tokenized Strategy: `0xb27064A2C51b8C5b39A5Bb911AD34DB039C3aB9c`

**Verdict: YES, we can build it.** 

Not only is the integration technically feasible, but the two systems are mathematically and structurally aligned because **Octant's `MorphoCompounderStrategy` is an ERC-4626 vault**, which is precisely the standard interface required by PEN's `PrincipalManager`. Furthermore, Octant already has a canonical precedent (`partners/shutter_dao_0x36`) showing exact parameters and deployment scripts.

However, our research reveals **crucial nuances and architectural differences** between standard yield vaults and Octant's yield-donating model that must be handled precisely in the test harness to achieve an indisputable proof.

---

## 1. Deep Analysis of the Two Systems

### 1.1 Shutter PEN Architecture
PEN is an on-chain capital formation and endowment engine:
* **`SeatToken`**: Non-transferable `ERC20Votes` token with 0 decimals (`1 SEAT = 1 vote`).
* **`BondingTranche`**: Facilitates seat purchases along a tranche pricing curve and guarantees a fixed refund price (`refundPrice = 0.50 USDC = 500_000 units`).
  * Crucially, before executing any refund, `BondingTranche.refund()` checks:
    $$\text{managedAssets} \ge \text{totalSupply} \times \text{refundPrice}$$
    If total managed assets cannot back the entire refund obligation of all minted seats, refunds are blocked (`RefundObligationExceedsManagedAssets`).
* **`PrincipalManager`**:
  * Receives purchase proceeds (USDC) from `BondingTranche`.
  * Maintains an internal `accountedPrincipal` tracking total purchase obligations.
  * Automatically routes liquid USDC above `liquidReserveTarget` into `principalVault` (an `IERC4626` vault).
  * Measures `totalManagedAssets = liquidAssets + deployedAssets`.
  * Computes `availableYield = max(totalManagedAssets - accountedPrincipal, 0)`.
  * Executes governance funding payouts via `executeFunding()` directly from liquid/withdrawn assets **without** decreasing `accountedPrincipal`.

### 1.2 Octant 1.3.0 Yield-Donating Strategy Architecture
Octant's `MorphoCompounderStrategy` (and base `YieldDonatingTokenizedStrategy`):
* Wraps an underlying yield vault (Yearn V3 / Morpho Steakhouse USDC `0x074134...`).
* **Yield Donation Mechanism**: Unlike standard ERC-4626 vaults where yield increases the price per share (PPS) for depositors, Octant's strategy **pegs PPS to 1:1** and **mints new shares equal to the profit directly to the `donationAddress` (`dragonRouter`)** upon calling `report()`.
* **Burning / Loss Protection**:
  * If `enableBurning == true`, when losses occur, shares held by the `donationAddress` are burned first.
  * The project document specifically specifies: **`donation-share burning disabled` (`_enableBurning = false`)** and the **PEN Governance Safe set as the donation recipient (`_donationAddress = Safe`)**.
* **First Depositor Protection (`MINIMUM_LIQUIDITY`)**:
  * On initial deposit, `1_000` shares (dead shares) are permanently minted to `0x000000000000000000000000000000000000dEaD`.

---

## 2. Key Architectural Discovery: The Yield Routing Loop

In a standard PEN deployment with a standard ERC-4626 vault:
1. `PrincipalManager` deposits USDC into Vault $\rightarrow$ receives Vault Shares.
2. The Vault generates yield $\rightarrow$ Vault shares become worth more assets (`vault.convertToAssets(shares)` increases).
3. `PrincipalManager.totalManagedAssets()` increases automatically.
4. `PrincipalManager.availableYield()` becomes positive.
5. Governance calls `PrincipalManager.executeFunding()` to pay grants.

**In the Octant Yield-Donating Strategy:**
1. `PrincipalManager` deposits USDC into `MorphoCompounderStrategy` $\rightarrow$ receives Strategy Shares.
2. The underlying Morpho vault earns profit.
3. Keeper calls `report()`.
4. The strategy **does not increase the PPS of PrincipalManager's shares**. Instead, it **mints brand-new strategy shares to the `donationAddress` (PEN Safe)**!
5. As long as those donation shares sit in the PEN Safe, `PrincipalManager` owns **0** of them. Consequently, inside `PrincipalManager`:
   - `PrincipalManager.totalManagedAssets()` remains equal to its principal.
   - `PrincipalManager.availableYield()` is **0**!
6. To make this donated yield available for PEN funding (as required in requirements §4 & §11 of `shutter.txt`):
   - The Safe must **redeem its donation shares** for USDC.
   - That USDC must be **transferred into `PrincipalManager`**.
   - Now, `liquidAssets()` in `PrincipalManager` increases by the yield amount, while `accountedPrincipal` remains unchanged.
   - **`availableYield()` now reflects the surplus**, and `PrincipalManager.executeFunding()` can disburse it!

This confirms the exact workflow outlined in `shutter.txt` and proves why this integration proof is vital to the Shutter & Octant communities.

---

## 3. What We Need to Build It (Prerequisites & Stack)

To build the test package, the following components are required:

### 3.1 Software & Tooling
* **Foundry Toolkit**: `forge` (v1.5+), `cast`, `anvil`.
* **Solidity Compiler**: `solc` 0.8.25 / 0.8.28 (PEN uses `^0.8.24`, Octant uses `>=0.8.25`).
* **Node.js / Bun / Python**: Optional helper scripts, but pure Foundry (`forge test`, `forge script`) should be the primary executable surface.

### 3.2 Pinned Repositories & Dependencies
We must pin exact commits for reproducibility:
1. **PEN Repository**: Pinned to commit `af2d08c` (matching deployment `0x187f287` / `0x1887d2e`).
2. **Octant Repository**: Pinned to tag `1.3.0` (`06ae2b9fa2e4443a3d9f6148498d4ada4f9861e8`).
3. **OpenZeppelin Contracts**:
   - Octant uses OZ v5.3.0.
   - PEN uses OZ v5.0.0 (compatible interfaces).
4. **Mainnet Fork Block**:
   - A pinned recent block where Yearn/Morpho Steakhouse vault `0x074134A2784F4F66b6ceD6f68849382990Ff3215` has active liquidity and valid oracle data (e.g., block `26129200` or the post-bootstrap block `25725000`).

### 3.3 Mainnet Contracts & Entities Needed
| Entity | Address | Role in Test |
|---|---|---|
| **PEN Safe** | `0xB7f69C3cd9E3dFB4aE0Ed9ee65eb2Ed42EdeECE3` | Governance owner of PEN, donation recipient |
| **PEN PrincipalManager** | `0x4517651c7071fecDA97Eb656a9d3A50B92b84517` | Treasury controller |
| **PEN BondingTranche** | `0x652a9A770f9Cfe26e409Aa63E84B8a4e21abe1e5` | Seat sales and refund coordinator |
| **PEN SeatToken** | `0xe2F401A0fb40dA191b9fa8C44Fa09D31cE17374c` | Governance membership token |
| **USDC** | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | Payment & underlying asset (6 decimals) |
| **Yearn Strategy USDC** | `0x074134A2784F4F66b6ceD6f68849382990Ff3215` | Compounder target vault |
| **Steakhouse USDC** | `0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB` | Underlying Morpho Blue vault |
| **Octant V1 Factory** | `0x052d20B0e0b141988bD32772C735085e45F357c1` | Deploys `MorphoCompounderStrategy` |
| **Octant Tokenized Strategy** | `0xb27064A2C51b8C5b39A5Bb911AD34DB039C3aB9c` | Implementation logic for Octant strategies |

---

## 4. How Best to Build It: System Architecture & Test Plan

To satisfy all MVP deliverables and requirements in `shutter.txt`, the test suite must be built around a clean, self-contained Foundry project structured as follows:

```
shutter-octant-integration/
├── .env.example
├── foundry.toml
├── remappings.txt
├── lib/
│   ├── forge-std/
│   ├── openzeppelin-contracts/
│   ├── perpetual-endowment-network/   (or submodule / clean src copy)
│   └── octant-v2-core/                 (or submodule / clean src copy)
├── src/
│   └── (Interfaces or test harness adapters if needed)
├── test/
│   ├── IntegrationBase.t.sol           (Fork setup, impersonations, deployment)
│   ├── 01_DepositAndYieldRouting.t.sol (Purchase SEAT, deposit, synthetic profit, report())
│   ├── 02_YieldRealizationAndRefund.t.sol (Redeem donation shares, fund PEN, refund SEAT)
│   └── 03_NegativeTests.t.sol          (Unauthorized report, diverted yield accounting)
└── RESULTS.md                          (Comprehensive accounting matrix & log output)
```

### Detailed Scenario Walkthrough

#### Stage 1: Setup & Strategy Deployment (`IntegrationBase.t.sol`)
1. Create fork at pinned block with an RPC URL (e.g., Alchemy / Infura / PublicNode).
2. Deploy `MorphoCompounderStrategy` locally via `createStrategy` with:
   - `_name`: `"PEN Octant Morpho USDC Strategy"`
   - `_management`: PEN Safe (`0xB7f6...`)
   - `_keeper`: Dedicated Keeper EOA
   - `_emergencyAdmin`: PEN Safe
   - `_donationAddress`: PEN Safe (`0xB7f6...`)
   - `_enableBurning`: `false` (as explicitly mandated in `shutter.txt`)
   - `_tokenizedStrategyAddress`: `0xb27064A2C51b8C5b39A5Bb911AD34DB039C3aB9c`
3. Impersonate the PEN Safe (via `vm.startPrank(SAFE)`) to call `PrincipalManager.setPrincipalVault(IERC4626(strategyAddress))`.
4. Configure `liquidReserveTarget` to a test value (e.g., $100$ USDC) so that any excess from seat purchases automatically deposits into the strategy.

#### Stage 2: Deposit & Yield Routing Demonstration (`01_DepositAndYieldRouting.t.sol`)
1. Give a test buyer USDC and approve `BondingTranche`.
2. Buyer purchases $10$ SEATs via `BondingTranche.purchase(buyer, 10, maxCost)`.
3. Assert:
   - `SeatToken.balanceOf(buyer) == 10`.
   - `PrincipalManager.accountedPrincipal` increased by the exact purchase cost.
   - `PrincipalManager` kept the `liquidReserveTarget` in liquid USDC and forwarded the excess into the Octant strategy.
   - `PrincipalManager` holds the resulting strategy shares.
4. **Synthetic Profit Injection**:
   - Deal synthetic USDC profit directly into the strategy contract or underlying vault (e.g., `deal(USDC, strategyAddress, balance + profit)`).
5. **Real Yield Report**:
   - Call `strategy.report()` as the authorized keeper (do **not** manually mint shares).
   - Assert:
     - `DonationMinted` event is emitted.
     - Donation shares are minted directly to **PEN Safe** (`0xB7f6...`).
     - Strategy's `pricePerShare()` remains 1:1.
     - `PrincipalManager` share balance does **not** change.

#### Stage 3: Yield Realization & Deep Refund (`02_YieldRealizationAndRefund.t.sol`)
1. **Redeem & Transfer**:
   - Safe redeems its donation shares for USDC via `strategy.redeem(shares, address(Safe), address(Safe))`.
   - Safe transfers that USDC into `PrincipalManager`.
2. **Accounting Audit**:
   - `PrincipalManager.totalManagedAssets()` is now strictly greater than `accountedPrincipal`.
   - `PrincipalManager.availableYield()` matches the realized profit.
3. **Deep Refund Execution**:
   - Drain `PrincipalManager`'s liquid USDC reserve to near zero (or set `liquidReserveTarget = 0` and deposit it all into the vault) so that a SEAT refund **must invoke an ERC-4626 withdrawal from the Octant vault**, not just consume existing idle cash.
   - Buyer calls `BondingTranche.refund(1, buyer)`.
   - Assert:
     - `SeatToken.burn()` burned 1 SEAT.
     - `PrincipalManager` pulled assets from the Octant strategy (triggering `vault.withdraw` and underlying Morpho unwrap).
     - Buyer received exactly `1 * refundPrice` ($0.50$ USDC).
     - `accountedPrincipal` decreased by $0.50$ USDC.

#### Stage 4: Negative Tests (`03_NegativeTests.t.sol`)
1. **Unauthorized Reporting**:
   - An arbitrary unauthorized EOA calls `strategy.report()`.
   - Must revert with `"!keeper"` (as enforced by `YieldDonatingTokenizedStrategy.onlyKeepers`).
2. **Yield Diverted Elsewhere**:
   - If another strategy is deployed with `donationAddress = Attacker/RandomDAO`, when `report()` runs, shares are minted to that third party.
   - Assert that neither PEN Safe nor `PrincipalManager` receives shares or assets, and PEN's `totalManagedAssets` and `availableYield` remain unchanged.

---

## 5. Potential Pitfalls, Edge Cases & How to Address Them

| Challenge / Edge Case | Risk | Solution / Mitigation |
|---|---|---|
| **ERC-4626 Minimum Liquidity (1,000 dead shares)** | On the first deposit, Octant's strategy burns 1,000 base units ($0.001$ USDC) to `0xdead`. In PEN, `accountedPrincipal` records the gross USDC amount deposited, so `totalManagedAssets` could initially be 1,000 units less than `accountedPrincipal`. | Document this initial rounding loss explicitly in `RESULTS.md`. In the test, seed the strategy with an initial negligible deposit or ensure the initial purchase comfortably exceeds 1,000 units. |
| **Decimals & Unit Scales** | `SeatToken` has 0 decimals; USDC has 6 decimals. Tranche prices are in 6-decimal USDC units. | Use exact constants (`1e6` for USDC, integer scalars for seats). |
| **Max Loss on Withdrawal** | `MorphoCompounderStrategy._freeFunds` uses `maxLoss = 10_000` (100% loss acceptance) on withdrawal to avoid revert cascades. | PEN's `PrincipalManager._ensureLiquidity` calls standard `vault.withdraw(shortfall, address(this), address(this))`. Since Octant's `withdraw` wrapper satisfies standard `IERC4626`, it integrates seamlessly. |
| **Safe Execution on Fork** | The PEN Safe on mainnet is owned by the Snapshot X execution strategy (`0x4D52...`). In a script/test, calling Safe methods directly normally requires signatures. | Use Foundry's `vm.prank(SAFE)` / `vm.startPrank(SAFE)` to simulate transactions dispatched by the Safe itself, accurately modeling the result of an executed governance proposal. |
| **Compounding vs Harvest Timing** | Morpho Steakhouse yield accrues continuously via interest rates, but Octant captures it discretely upon `report()`. | Tests will explicitly simulate discrete epochs using `deal` or time-warps with real accrued interest followed by an explicit `report()`. |

---

## 6. Implementation Roadmap

### Phase 1: Repository & Test Environment Setup
- Initialize clean Foundry project.
- Configure `foundry.toml` with EVM version `prague`/`cancun`, optimizer, and remappings.
- Vendor or link PEN core contracts and Octant 1.3.0 strategy contracts.
- Establish `IntegrationBase.t.sol` with reproducible mainnet fork settings.

### Phase 2: Core Flow Implementation & Test Execution
- Implement `01_DepositAndYieldRouting.t.sol`.
- Implement `02_YieldRealizationAndRefund.t.sol`.
- Implement `03_NegativeTests.t.sol`.
- Execute tests and capture comprehensive event logs, gas usage, and balance traces.

### Phase 3: Deliverables & Documentation
- Write `RESULTS.md` with:
  - Exact breakdown of share ownership across entities (Buyer, PrincipalManager, Safe, `0xdead`).
  - Total managed assets vs. accounted principal vs. refund obligation vs. available surplus.
  - Rounding analysis (including the 1,000-unit dead share cost).
  - Explicit list of all impersonated actors and synthetic inputs.
- Polish `README.md` with 1-command reproduction steps (`forge test`).

---

## 7. Conclusion

The proposed integration is **fully sound and viable**. Octant's architecture cleanly separates principal preservation from yield donation, and Shutter PEN's `PrincipalManager` and `BondingTranche` are built to handle standard ERC-4626 vaults.

The only structural bridge required is **Safe-mediated yield realization** (Safe redeems its donated strategy shares and transfers the USDC into `PrincipalManager`). Demonstrating this in a reproducible Foundry test package will deliver complete clarity and proof to proposal reviewers and developers.
