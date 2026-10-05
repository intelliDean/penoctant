// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase, console2} from "./IntegrationBase.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorphoCompounderStrategyFactoryV1} from "src/interfaces/IMorphoCompounderStrategyFactoryV1.sol";
import {ITokenizedStrategy} from "src/core/interfaces/ITokenizedStrategy.sol";
import {IBaseHealthCheck} from "src/strategies/interfaces/IBaseHealthCheck.sol";

/**
 * @title NegativeTests
 * @notice Requirement §12: Add two negative tests.
 *  - Negative Test 1: Confirm that unauthorized reporting fails (reverts with !keeper).
 *  - Negative Test 2: Confirm that yield sent to another recipient is not incorrectly counted as available to PEN.
 */
contract NegativeTests is IntegrationBase {

    address public unauthorizedCaller = makeAddr("unauthorizedCaller");
    address public thirdPartyDonationRecipient = makeAddr("thirdPartyDonationRecipient");

    /**
     * @notice Negative Test 1: Unauthorized reporting must revert.
     */
    function test_Negative_UnauthorizedReportFails() public {
        console2.log("=== NEGATIVE TEST 1: UNAUTHORIZED REPORTING ===");
        // Ensure caller is neither keeper nor management
        assertTrue(unauthorizedCaller != keeper, "Caller is not keeper");
        assertTrue(unauthorizedCaller != PEN_SAFE, "Caller is not management");

        // Attempting to call report() as an unauthorized user must revert with "!keeper"
        vm.prank(unauthorizedCaller);
        vm.expectRevert("!keeper");
        strategy.report();

        console2.log("Passed: Unauthorized report successfully reverted with '!keeper'");
    }

    /**
     * @notice Negative Test 2: Yield routed to another recipient is NOT counted in PEN.
     */
    function test_Negative_DivertedYieldNotCountedAsAvailableToPEN() public {
        console2.log("=== NEGATIVE TEST 2: DIVERTED YIELD ROUTING ===");
        
        // 1. Deploy an alternate strategy with donationAddress pointing to thirdPartyDonationRecipient
        string memory alternateName = "Diverted Yield Strategy";
        vm.prank(PEN_SAFE);
        address alternateStrategyAddress = IMorphoCompounderStrategyFactoryV1(OCTANT_FACTORY_V1).createStrategy(
            alternateName,
            PEN_SAFE,                      // _management
            keeper,                        // _keeper
            PEN_SAFE,                      // _emergencyAdmin
            thirdPartyDonationRecipient,   // _donationAddress (diverted recipient)
            false,                         // _enableBurning
            OCTANT_TOKENIZED_STRATEGY
        );

        ITokenizedStrategy alternateStrategy = ITokenizedStrategy(alternateStrategyAddress);

        // Configure PEN's principal vault to this alternate strategy
        vm.startPrank(PEN_SAFE);
        principalManager.setPrincipalVault(alternateStrategy);
        principalManager.setLiquidReserveTarget(50_000_000); // 50 USDC
        vm.stopPrank();

        // 2. Buyer purchases seats to seed the position
        uint256 seatsToBuy = 5;
        uint256 quote = bondingTranche.quotePurchase(seatsToBuy);
        deal(MAINNET_USDC, buyer2, quote);

        vm.startPrank(buyer2);
        IERC20(MAINNET_USDC).approve(address(bondingTranche), quote);
        bondingTranche.purchase(buyer2, seatsToBuy, quote);
        vm.stopPrank();

        uint256 penManagedAssetsBefore = principalManager.totalManagedAssets();
        uint256 penAccountedPrincipalBefore = principalManager.accountedPrincipal();
        uint256 penAvailableYieldBefore = principalManager.availableYield();

        // 3. Inject synthetic profit and harvest
        uint256 syntheticProfit = 300_000_000; // 300 USDC
        deal(MAINNET_USDC, alternateStrategyAddress, IERC20(MAINNET_USDC).balanceOf(alternateStrategyAddress) + syntheticProfit);

        // Disable healthCheck for test harvest of outsized synthetic profit
        vm.prank(PEN_SAFE);
        IBaseHealthCheck(alternateStrategyAddress).setDoHealthCheck(false);

        vm.prank(keeper);
        alternateStrategy.report();

        // 4. Verify where shares landed
        uint256 thirdPartyShares = alternateStrategy.balanceOf(thirdPartyDonationRecipient);
        uint256 safeShares = alternateStrategy.balanceOf(PEN_SAFE);
        uint256 pmShares = alternateStrategy.balanceOf(address(principalManager));

        console2.log("Third Party Received Shares:       ", thirdPartyShares);
        console2.log("PEN Safe Received Shares:          ", safeShares);
        console2.log("PEN PrincipalManager Received Shares:", pmShares);

        assertTrue(thirdPartyShares > 0, "Third party must receive all donation shares");
        assertEq(safeShares, 0, "PEN Safe must receive 0 donation shares");

        // 5. Verify PEN accounting did NOT count this profit as available yield
        uint256 penManagedAssetsAfter = principalManager.totalManagedAssets();
        uint256 penAccountedPrincipalAfter = principalManager.accountedPrincipal();
        uint256 penAvailableYieldAfter = principalManager.availableYield();

        console2.log("PEN Managed Assets After Report:    ", penManagedAssetsAfter);
        console2.log("PEN Accounted Principal After Report:", penAccountedPrincipalAfter);
        console2.log("PEN Available Yield After Report:    ", penAvailableYieldAfter);

        assertEq(penAvailableYieldAfter, 0, "Available yield in PEN must remain 0");
        assertEq(penAvailableYieldAfter, penAvailableYieldBefore, "Yield sent to external recipient must not benefit PEN");
        assertEq(penManagedAssetsAfter, penManagedAssetsBefore, "Total managed assets must not increase from diverted yield");
        assertEq(penAccountedPrincipalAfter, penAccountedPrincipalBefore, "Principal obligation unchanged");
        
        console2.log("Passed: Diverted yield is completely isolated from PEN accounting");
    }
}
