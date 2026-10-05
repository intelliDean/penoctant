// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import { YieldSkimmingTokenizedStrategy } from "./YieldSkimmingTokenizedStrategy.sol";
import { Privileged } from "src/core/Privileged.sol";

/**
 * @title Privileged Yield Skimming Tokenized Strategy
 * @author [Golem Foundation](https://golem.foundation)
 * @custom:security-contact security@golem.foundation
 * @notice YieldSkimmingTokenizedStrategy with privileged-gated deposits and mints.
 */
contract PrivilegedYieldSkimmingTokenizedStrategy is YieldSkimmingTokenizedStrategy, Privileged {
    /// @notice Grant or revoke privileged status for a single account.
    function setPrivileged(address _account, bool _status) external onlyManagement {
        _setPrivileged(_account, _status);
    }

    /// @notice Grant or revoke privileged status for a batch of accounts.
    function setPrivilegedBatch(address[] calldata _accounts, bool _status) external onlyManagement {
        _setPrivilegedBatch(_accounts, _status);
    }

    /// @notice Deposit assets from a privileged caller. The receiver does not need to be privileged.
    /// @dev Only the caller is gated. A receiver-side check would be redundant because
    ///      ERC-20 transfers are ungated, so once shares are minted they can move to any
    ///      address. Restricting to caller-only unblocks legitimate mint-to-contract flows
    ///      (splitters, aggregators, integrator vaults) while preserving the real trust
    ///      boundary: who can initiate new share issuance.
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        require(isPrivileged(msg.sender), "!privileged");
        return super.deposit(assets, receiver);
    }

    /// @notice Mint shares from a privileged caller. The receiver does not need to be privileged.
    /// @dev Caller-only gate; see `deposit` for the rationale.
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        require(isPrivileged(msg.sender), "!privileged");
        return super.mint(shares, receiver);
    }

    /// @notice Returns 0 for non-privileged receivers so front-ends steer users toward the
    ///         privileged path; a privileged caller may still deposit on their behalf.
    function maxDeposit(address receiver) public view override returns (uint256) {
        if (!isPrivileged(receiver)) return 0;
        return super.maxDeposit(receiver);
    }

    /// @notice Returns 0 for non-privileged receivers so front-ends steer users toward the
    ///         privileged path; a privileged caller may still mint on their behalf.
    function maxMint(address receiver) public view override returns (uint256) {
        if (!isPrivileged(receiver)) return 0;
        return super.maxMint(receiver);
    }
}
