// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.25;

import { ERC4626Strategy } from "src/strategies/yieldDonating/ERC4626Strategy.sol";
import { BaseERC4626StrategyFactory } from "src/factories/BaseERC4626StrategyFactory.sol";

/**
 * @title ERC4626StrategyFactory
 * @author [Golem Foundation](https://golem.foundation)
 * @custom:security-contact security@golem.foundation
 * @notice Factory for deploying ERC4626 yield donating strategies
 * @dev Uses CREATE2 for deterministic deployments; records deployments via BaseStrategyFactory
 *
 *      ERC4626 INTEGRATION:
 *      This factory deploys strategies that can deposit into any ERC4626-compliant vault,
 *      including SparkDAO vaults, Yearn v3 vaults, or any other standard ERC4626 implementation.
 *      The underlying vault must have manipulation-resistant accounting.
 */
contract ERC4626StrategyFactory is BaseERC4626StrategyFactory {
    /// @inheritdoc BaseERC4626StrategyFactory
    function _getCreationCode() internal pure override returns (bytes memory) {
        return type(ERC4626Strategy).creationCode;
    }
}
