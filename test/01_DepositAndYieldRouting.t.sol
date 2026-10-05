// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase, console2} from "./IntegrationBase.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBaseHealthCheck} from "src/strategies/interfaces/IBaseHealthCheck.sol";

/**
 * @title DepositAndYieldRoutingTest
 * @notice Requirement §9: Demonstrate deposit and yield routing.
 *  - Purchase test SEATs through PEN and confirm that PrincipalManager receives the strategy shares.
 *  - Introduce clearly labeled synthetic profit, call Octant's actual reporting function,
 *    and verify where donation shares are minted. Do not manufacture the expected shares manually.
 */
contract DepositAndYieldRoutingTest is IntegrationBase {

    function test_DepositAndYieldRoutingFlow() public {
        console2.log("=== STEP 1: INITIAL STATE ===");
        uint256 initialPrincipal = principalManager.accountedPrincipal();
        uint256 initialManagedAssets = principalManager.totalManagedAssets();
        uint256 initialSupply = seatToken.totalSupply();
        console2.log("Initial Accounted Principal:", initialPrincipal);
        console2.log("Initial Managed Assets:     ", initialManagedAssets);
        console2.log("Initial SEAT Total Supply:  ", initialSupply);

        // ══════════════════════════════════════════════════════════════════════════
        // 1. SEAT PURCHASE & DEPOSIT ROUTING
        // ══════════════════════════════════════════════════════════════════════════
        uint256 seatsToBuy = 5;
        uint256 quote = bondingTranche.quotePurchase(seatsToBuy);
        console2.log("Quoted cost for 5 SEATs:    ", quote);

        // Fund buyer with USDC and approve BondingTranche
        deal(MAINNET_USDC, buyer1, quote);
        vm.startPrank(buyer1);
        IERC20(MAINNET_USDC).approve(address(bondingTranche), quote);
        bondingTranche.purchase(buyer1, seatsToBuy, quote);
        vm.stopPrank();

        // Verifications post-purchase
        assertEq(seatToken.balanceOf(buyer1), seatsToBuy, "Buyer should hold 5 SEATs");
        assertEq(principalManager.accountedPrincipal(), initialPrincipal + quote, "Accounted principal must increase by cost");

        uint256 pmStrategyShares = strategy.balanceOf(address(principalManager));
        console2.log("PrincipalManager Strategy Shares:", pmStrategyShares);
        assertTrue(pmStrategyShares > 0, "PrincipalManager must receive strategy shares");

        // Note: The mainnet deployed Octant TokenizedStrategy implementation does not burn dead shares to 0xdead.
        console2.log("Dead shares at 0xdead:          ", strategy.balanceOf(address(0xdead)));

        // ══════════════════════════════════════════════════════════════════════════
        // 2. SYNTHETIC PROFIT & ACTUAL OCTANT REPORTING
        // ══════════════════════════════════════════════════════════════════════════
        console2.log("\n=== STEP 2: INTRODUCING SYNTHETIC PROFIT ===");
        // Introduce clearly labeled synthetic profit: 500 USDC
        uint256 syntheticProfit = 500_000_000; // 500 USDC (6 decimals)
        
        // Inject profit into the strategy's asset balance
        deal(MAINNET_USDC, strategyAddress, IERC20(MAINNET_USDC).balanceOf(strategyAddress) + syntheticProfit);
        console2.log("Strategy total assets before report:", strategy.totalAssets());

        // Safe donation share balance before report
        uint256 safeDonationSharesBefore = strategy.balanceOf(PEN_SAFE);
        assertEq(safeDonationSharesBefore, 0, "Safe should have 0 donation shares prior to report");

        // BaseHealthCheck protects against profit leaps > 100% in a single harvest.
        // For testing large synthetic jumps, management disables health check for the test harvest.
        vm.prank(PEN_SAFE);
        IBaseHealthCheck(strategyAddress).setDoHealthCheck(false);

        // Call Octant's actual report function as the authorized keeper
        vm.prank(keeper);
        (uint256 reportedProfit, uint256 reportedLoss) = strategy.report();

        console2.log("Reported Profit from harvest:", reportedProfit);
        console2.log("Reported Loss:               ", reportedLoss);
        assertApproxEqAbs(reportedProfit, syntheticProfit, 10, "Reported profit must capture the synthetic profit within rounding");
        assertEq(reportedLoss, 0, "Loss must be zero");

        // ══════════════════════════════════════════════════════════════════════════
        // 3. VERIFY DONATION SHARE MINTING DESTINATION
        // ══════════════════════════════════════════════════════════════════════════
        uint256 safeDonationSharesAfter = strategy.balanceOf(PEN_SAFE);
        uint256 pmSharesAfterReport = strategy.balanceOf(address(principalManager));

        console2.log("Safe Donation Shares After:      ", safeDonationSharesAfter);
        console2.log("PrincipalManager Shares After:   ", pmSharesAfterReport);

        // Core Assertion: Donation shares are minted to PEN Safe, NOT PrincipalManager
        assertTrue(safeDonationSharesAfter > 0, "Donation shares MUST be minted to PEN Safe");
        assertEq(pmSharesAfterReport, pmStrategyShares, "PrincipalManager shares MUST NOT change from report()");
        
        // Strategy PPS remains 1:1 (in base units)
        assertEq(strategy.pricePerShare(), 1e6, "Octant strategy share price must remain 1:1");
    }
}
