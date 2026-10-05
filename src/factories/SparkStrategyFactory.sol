// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.25;

import { SparkStrategy } from "src/strategies/yieldDonating/SparkStrategy.sol";
import { BaseERC4626StrategyFactory } from "src/factories/BaseERC4626StrategyFactory.sol";

/**
 * @title SparkStrategyFactory
 * @author [Golem Foundation](https://golem.foundation)
 * @custom:security-contact security@golem.foundation
 * @notice Factory for deploying Spark yield donating strategies with airdrop sweep functionality
 * @dev Uses CREATE2 for deterministic deployments; records deployments via BaseStrategyFactory
 *
 *      SPARK INTEGRATION:
 *      This factory deploys strategies specifically designed for Spark Protocol ERC4626 vaults.
 *      These strategies include additional functionality to sweep airdropped tokens (like airdropped
 *      tokens) to the donation address
 */
contract SparkStrategyFactory is BaseERC4626StrategyFactory {
    /// @inheritdoc BaseERC4626StrategyFactory
    function _getCreationCode() internal pure override returns (bytes memory) {
        return type(SparkStrategy).creationCode;
    }
}
