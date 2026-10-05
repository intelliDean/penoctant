# PEN–Octant Integration Proof: Results & Accounting Audit

## Executive Summary

This document presents the empirical verification and accounting audit of the integration between the **Perpetual Endowment Network (PEN)** and **Octant V1/V2 Yield-Donating Strategies**.

The verification was executed as a Foundry test suite against a local Ethereum mainnet fork, interacting directly with:
- **Shutter PEN Deployed Contracts**: `PrincipalManager` (`0x4517651c...`), `BondingTranche` (`0x652a9A77...`), and `SeatToken` (`0xe2F401A0...`).
- **Octant Mainnet Infrastructure**: `MorphoCompounderStrategyFactoryV1` (`0x052d20B0...`), `YieldDonatingTokenizedStrategy` (`0xb27064A2...`), and Morpho Steakhouse USDC Vault (`0xBEEF0173...`).

All four test cases passed with zero compilation errors and zero warnings.

---

## Complete Test Results

| Test Suite | Test Case | Status | Gas Used | Core Invariant Verified |
| :--- | :--- | :---: | :---: | :--- |
| `01_DepositAndYieldRouting.t.sol` | `test_DepositAndYieldRoutingFlow` | **PASS** | 1,821,892 | SEAT purchase deploys USDC to Octant strategy; `report()` mints donation shares **exclusively** to PEN Safe; PM shares remain unchanged; PPS remains 1:1. |
| `02_YieldRealizationAndRefund.t.sol` | `test_YieldRealizationAndDeepRefund` | **PASS** | 4,752,685 | PEN Safe redeems donation shares to USDC; transfer to PM unlocks `availableYield`; deep SEAT refund executes an ERC-4626 vault withdrawal when liquid reserves are zero. |
| `03_NegativeTests.t.sol` | `test_Negative_UnauthorizedReportFails` | **PASS** | 31,527 | Unauthorized callers attempting `strategy.report()` revert with `!keeper`. |
| `03_NegativeTests.t.sol` | `test_Negative_DivertedYieldNotCountedAsAvailableToPEN` | **PASS** | 3,004,573 | Diverting strategy `donationAddress` to an external entity routes 100% of profit shares away from PEN; PEN `availableYield` remains strictly 0. |

---

## Detailed Accounting & Balance Audit

All token and share quantities are shown in native units (USDC and strategy shares use 6 decimals).

### 1. Share Ownership Lifecycle

| Lifecycle Stage | SeatBuyer1 (SEAT) | PrincipalManager (Shares) | PEN Safe (Shares) | ThirdParty (Shares) | Dead Shares (`0xdead`) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Initial Fork State** | 0 | 0 | 0 | 0 | 0 |
| **After 5 SEAT Purchase** | 5 | 56,000,000 | 0 | 0 | 0 |
| **After 500 USDC Profit Report** | 5 | 56,000,000 | 499,999,999 | 0 | 0 |
| **After Safe Yield Realization** | 5 | 56,000,000 | 0 *(Redeemed)* | 0 | 0 |
| **After 1 SEAT Deep Refund** | 4 | 55,500,000 | 0 | 0 | 0 |
| **Diverted Strategy Test** | 5 | 56,000,000 | 0 | 299,999,998 | 0 |

> **Key Observation on Dead Shares**: The live Ethereum mainnet implementation at `0xb27064A2C51b8C5b39A5Bb911AD34DB039C3aB9c` does not burn 1,000 dead shares to `address(0xdead)` upon initial deposit. Shares are minted 1:1 directly to `PrincipalManager`.

---

### 2. PEN Treasury Accounting Progression

$$\text{Available Yield} = \max(0, \text{Total Managed Assets} - \text{Accounted Principal})$$

| Lifecycle Stage | Total Managed Assets | Accounted Principal | Total Refund Obligation | Available Yield | Liquid USDC in PM | Strategy Deployed Assets |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Initial Fork State** | 101,000,000 | 101,000,000 | 50,000,000 | **0** | 101,000,000 | 0 |
| **2. Post-Purchase (5 SEATs @ 1 USDC)** | 106,000,000 | 106,000,000 | 52,500,000 | **0** | 50,000,000 | 56,000,000 |
| **3. Post-Harvest Report (+500 USDC yield)** | 106,000,000 | 106,000,000 | 52,500,000 | **0** | 50,000,000 | 56,000,000 |
| **4. Safe Realizes Yield (Transfers USDC to PM)** | 605,999,999 | 106,000,000 | 52,500,000 | **499,999,999** | 549,999,999 | 56,000,000 |
| **5. Post-Funding Payout (100 USDC to Recipient)**| 505,999,999 | 106,000,000 | 52,500,000 | **399,999,999** | 449,999,999 | 56,000,000 |
| **6. Post-Deep Refund (1 SEAT @ 0.50 USDC)** | 505,499,999 | 105,500,000 | 52,000,000 | **399,999,999** | 0 | 505,499,999 |

---

## Rounding Analysis & Asset Trapping Audit

1. **Integer Division Rounding**:
   - In Step 2, synthetic profit of `500,000,000` units (500.00 USDC) was supplied.
   - The reported profit and resulting donation shares totaled `499,999,999` units.
   - **Rounding cost**: Exactly `1` micro-USDC ($0.000001) due to integer division round-down in ERC-4626 `convertToAssets`.
2. **Price Per Share (PPS)**:
   - Octant strategy PPS remained invariant at `1,000,000` (1:1) throughout the lifecycle.
   - Profit is extracted by share inflation directed exclusively to the donation address, never by PPS growth.
3. **Asset Trapping**:
   - **Zero assets or shares are trapped**.
   - All donation shares were successfully redeemed 1:1 for underlying USDC by the Safe.
   - All principal shares held by PrincipalManager remained fully redeemable on demand to satisfy buyer refund obligations.

---

## Security Invariants & Behavioral Rules Verified

1. **Strict Yield Isolation**:
   - When Octant strategies harvest yield, `PrincipalManager.totalManagedAssets()` does **not** increase, and `PrincipalManager.availableYield()` remains **zero**.
   - Yield cannot be prematurely spent or diluted by PEN until the Safe explicitly claims and deposits the realized assets.
2. **Refund Solvency Under Low Liquidity**:
   - When `PrincipalManager` liquid cash was depleted to 0, `bondingTranche.refund(1, buyer1)` automatically triggered `_ensureLiquidity()`.
   - `PrincipalManager` initiated an ERC-4626 `vault.withdraw(500_000, ...)` against the Octant strategy, successfully burning 500,000 strategy shares and returning 0.50 USDC to the buyer.
3. **Access Controls**:
   - Unauthorized attempts to call `strategy.report()` reverted with `!keeper`.
   - `BaseHealthCheck` protected against profit leaps > 100% APR in a single harvest block, requiring management intervention (`setDoHealthCheck(false)` or `setProfitLimitRatio`) if unexpected spikes occur.

---

## Environment & Test Configuration

- **Execution Environment**: Foundry `forge` on local Ethereum mainnet fork.
- **RPC Gateway**: `https://gateway.tenderly.co/public/mainnet`
- **Compiler**: Solc `0.8.25`, EVM version `cancun`, optimizer runs `200`.
- **Impersonated Test Actors**:
  - `PEN_SAFE` (`0xB7f69C3cd9E3dFB4aE0Ed9ee65eb2Ed42EdeECE3`): Governance multisig.
  - `keeper` (`0x3472de7Fc21584Fd5A60996DD2bC2C1fe39EaB27`): Authorized strategy keeper.
  - `seatBuyer1` (`0xC0F17C241B5091CE1517682b87f66454D9D0a8AE`): End user purchasing and refunding SEAT tokens.
  - `grantRecipient1` (`0xcFEa25692A62f30A2c78aF88D0c5bB909D1314C7`): Public goods grant recipient.
