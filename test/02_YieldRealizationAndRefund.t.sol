// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase, console2} from "./IntegrationBase.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBaseHealthCheck} from "src/strategies/interfaces/IBaseHealthCheck.sol";

/**
 * @title YieldRealizationAndRefundTest
 * @notice Requirement §11: Demonstrate yield realization and a refund.
 *  - Redeem the Safe's donation shares, transfer the resulting USDC into PrincipalManager,
 *    and record the accounting changes.
 *  - Exercise one SEAT refund that requires a vault withdrawal—not just existing liquid reserves.
 */
contract YieldRealizationAndRefundTest is IntegrationBase {

    function test_YieldRealizationAndDeepRefund() public {
        // 1. Setup position & accrue profit
        uint256 quote = bondingTranche.quotePurchase(5);
        
        deal(MAINNET_USDC, buyer1, quote);
        vm.startPrank(buyer1);
        IERC20(MAINNET_USDC).approve(address(bondingTranche), quote);
        bondingTranche.purchase(buyer1, 5, quote);
        vm.stopPrank();

        // Introduce synthetic profit (500 USDC) and call report()
        deal(MAINNET_USDC, strategyAddress, IERC20(MAINNET_USDC).balanceOf(strategyAddress) + 500_000_000);

        // Disable healthCheck for test harvest of outsized synthetic profit
        vm.prank(PEN_SAFE);
        IBaseHealthCheck(strategyAddress).setDoHealthCheck(false);

        vm.prank(keeper);
        strategy.report();

        uint256 safeShares = strategy.balanceOf(PEN_SAFE);
        assertTrue(safeShares > 0, "Safe must hold donation shares");

        console2.log("=== PRIOR TO YIELD REALIZATION ===");
        console2.log("Safe Donation Shares:        ", safeShares);
        console2.log("PM Accounted Principal:      ", principalManager.accountedPrincipal());
        console2.log("PM Total Managed Assets:     ", principalManager.totalManagedAssets());
        console2.log("PM Available Yield:          ", principalManager.availableYield());

        assertEq(principalManager.availableYield(), 0, "Available yield in PM is 0 before donation shares transferred");

        // 2. Redeem Safe donation shares & transfer USDC to PrincipalManager
        console2.log("\n=== REALIZING DONATED YIELD INTO PRINCIPALMANAGER ===");
        vm.startPrank(PEN_SAFE);
        uint256 redeemedUSDC = strategy.redeem(safeShares, PEN_SAFE, PEN_SAFE);
        console2.log("USDC redeemed by Safe from donation shares:", redeemedUSDC);
        assertTrue(redeemedUSDC > 0, "Redemption must yield USDC");

        IERC20(MAINNET_USDC).transfer(address(principalManager), redeemedUSDC);
        vm.stopPrank();

        // Audit accounting changes
        uint256 availableYieldAfter = principalManager.availableYield();
        console2.log("PM Total Managed Assets After: ", principalManager.totalManagedAssets());
        console2.log("PM Accounted Principal After:  ", principalManager.accountedPrincipal());
        console2.log("PM Available Yield After:      ", availableYieldAfter);

        assertTrue(availableYieldAfter >= redeemedUSDC, "Available yield must reflect realized donation USDC");

        // Demonstrate a governance yield funding payout
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100_000_000; // 100 USDC

        vm.prank(PEN_SAFE);
        principalManager.executeFunding(recipients, amounts);
        assertEq(IERC20(MAINNET_USDC).balanceOf(recipient1), 100_000_000, "Recipient received funding");

        // 3. Exercise deep SEAT refund requiring a vault withdrawal
        _exerciseDeepRefund();
    }

    function _exerciseDeepRefund() internal {
        console2.log("\n=== EXERCISING DEEP SEAT REFUND (VAULT WITHDRAWAL) ===");
        // Drain liquid USDC in PM into the vault
        vm.startPrank(PEN_SAFE);
        principalManager.setLiquidReserveTarget(0);
        principalManager.depositExcessToPrincipalVault();
        vm.stopPrank();

        assertEq(principalManager.liquidAssets(), 0, "Liquid cash in PM must be 0 to force vault withdrawal");

        // Buyer1 requests refund for 1 SEAT
        uint256 refundPrice = bondingTranche.refundPrice();
        uint256 buyerUSDCBefore = IERC20(MAINNET_USDC).balanceOf(buyer1);
        uint256 pmSharesBefore = strategy.balanceOf(address(principalManager));
        uint256 principalBefore = principalManager.accountedPrincipal();

        vm.prank(buyer1);
        bondingTranche.refund(1, buyer1);

        uint256 buyerUSDCAfter = IERC20(MAINNET_USDC).balanceOf(buyer1);
        uint256 pmSharesAfter = strategy.balanceOf(address(principalManager));
        uint256 principalAfter = principalManager.accountedPrincipal();

        console2.log("Buyer USDC received from refund:    ", buyerUSDCAfter - buyerUSDCBefore);
        console2.log("PrincipalManager Vault Shares Burned:", pmSharesBefore - pmSharesAfter);
        console2.log("Accounted Principal Reduction:       ", principalBefore - principalAfter);

        assertEq(buyerUSDCAfter - buyerUSDCBefore, refundPrice, "Buyer must receive exact refundPrice");
        assertEq(principalBefore - principalAfter, refundPrice, "Accounted principal must decrease by refundPrice");
        assertTrue(pmSharesBefore > pmSharesAfter, "Vault shares must be redeemed/withdrawn to pay refund");
        assertEq(seatToken.balanceOf(buyer1), 4, "Buyer seat count decremented");
    }
}
