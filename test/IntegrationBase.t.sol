// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {PrincipalManager} from "src/PrincipalManager.sol";
import {BondingTranche} from "src/BondingTranche.sol";
import {SeatToken} from "src/SeatToken.sol";
import {ITokenizedStrategy} from "src/core/interfaces/ITokenizedStrategy.sol";
import {IMorphoCompounderStrategyFactoryV1} from "src/interfaces/IMorphoCompounderStrategyFactoryV1.sol";
import {IBaseHealthCheck} from "src/strategies/interfaces/IBaseHealthCheck.sol";
import {
    USDC_MAINNET,
    MORPHO_STRATEGY_FACTORY_MAINNET,
    YIELD_DONATING_TOKENIZED_STRATEGY_MAINNET
} from "src/constants.sol";

abstract contract IntegrationBase is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // PINNED MAINNET IDENTITIES & ADDRESSES
    // ══════════════════════════════════════════════════════════════════════════════

    address public constant MAINNET_USDC = USDC_MAINNET; // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public constant YEARN_YS_USDC = 0x074134A2784F4F66b6ceD6f68849382990Ff3215;
    address public constant MORPHO_STEAKHOUSE_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    address public constant OCTANT_FACTORY_V1 = MORPHO_STRATEGY_FACTORY_MAINNET; // 0x052d20B0e0b141988bD32772C735085e45F357c1
    address public constant OCTANT_TOKENIZED_STRATEGY = YIELD_DONATING_TOKENIZED_STRATEGY_MAINNET; // 0xb27064A2C51b8C5b39A5Bb911AD34DB039C3aB9c

    // Pinned Shutter PEN mainnet deployment addresses
    address public constant PEN_SAFE = 0xB7f69C3cd9E3dFB4aE0Ed9ee65eb2Ed42EdeECE3;
    address public constant DEPLOYED_PRINCIPAL_MANAGER = 0x4517651c7071fecDA97Eb656a9d3A50B92b84517;
    address public constant DEPLOYED_BONDING_TRANCHE = 0x652a9A770f9Cfe26e409Aa63E84B8a4e21abe1e5;
    address public constant DEPLOYED_SEAT_TOKEN = 0xe2F401A0fb40dA191b9fa8C44Fa09D31cE17374c;

    // Test actors
    address public keeper = makeAddr("strategyKeeper");
    address public buyer1 = makeAddr("seatBuyer1");
    address public buyer2 = makeAddr("seatBuyer2");
    address public recipient1 = makeAddr("grantRecipient1");

    // Contracts under test
    PrincipalManager public principalManager;
    BondingTranche public bondingTranche;
    SeatToken public seatToken;
    ITokenizedStrategy public strategy;
    address public strategyAddress;

    // Pinned Fork Block (recent block with verified Steakhouse and PEN state)
    uint256 public constant FORK_BLOCK = 26129200;

    function setUp() public virtual {
        string memory rpcUrl = vm.envOr("ETH_RPC_URL", string("https://gateway.tenderly.co/public/mainnet"));
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        if (forkBlock > 0) {
            vm.createSelectFork(rpcUrl, forkBlock);
        } else {
            vm.createSelectFork(rpcUrl);
        }

        principalManager = PrincipalManager(DEPLOYED_PRINCIPAL_MANAGER);
        bondingTranche = BondingTranche(DEPLOYED_BONDING_TRANCHE);
        seatToken = SeatToken(DEPLOYED_SEAT_TOKEN);

        // Verify identities of deployed contracts on the fork
        assertEq(address(principalManager.asset()), MAINNET_USDC, "Identity mismatch: USDC");
        assertEq(address(bondingTranche.seatToken()), address(seatToken), "Identity mismatch: SeatToken");
        assertEq(address(bondingTranche.principalManager()), address(principalManager), "Identity mismatch: PrincipalManager");

        // Deploy candidate Octant strategy locally via the factory with:
        // - PEN governance Safe as donation-share recipient
        // - donation-share burning disabled (false)
        string memory strategyName = "PEN Octant Morpho USDC Strategy";
        
        vm.prank(PEN_SAFE);
        strategyAddress = IMorphoCompounderStrategyFactoryV1(OCTANT_FACTORY_V1).createStrategy(
            strategyName,
            PEN_SAFE,                  // _management
            keeper,                    // _keeper
            PEN_SAFE,                  // _emergencyAdmin
            PEN_SAFE,                  // _donationAddress (receives minted donation shares)
            false,                     // _enableBurning (disabled)
            OCTANT_TOKENIZED_STRATEGY  // _tokenizedStrategyAddress
        );

        strategy = ITokenizedStrategy(strategyAddress);

        // Configure PEN to point to the newly deployed strategy as its principalVault
        vm.startPrank(PEN_SAFE);
        principalManager.setPrincipalVault(IERC4626(strategyAddress));
        // Configure a sensible liquid reserve target (e.g. 50 USDC)
        principalManager.setLiquidReserveTarget(50_000_000);
        vm.stopPrank();

        // Verify configuration
        assertEq(address(principalManager.principalVault()), strategyAddress, "PrincipalVault configuration failed");
        assertEq(IERC4626(strategyAddress).asset(), MAINNET_USDC, "Strategy asset mismatch");
    }
}
