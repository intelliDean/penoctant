// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

/**
 * @title Privileged
 * @author [Golem Foundation](https://golem.foundation)
 * @custom:security-contact security@golem.foundation
 * @notice Mixin providing privileged address storage and management functions.
 * @dev Uses ERC-7201 namespaced storage to avoid collisions.
 *      Inheriting contracts must implement access control for setPrivileged/setPrivilegedBatch.
 */
abstract contract Privileged {
    event PrivilegedUpdated(address indexed account, bool status);

    bytes32 internal constant PRIVILEGED_STORAGE =
        keccak256(abi.encode(uint256(keccak256("octant.privileged.strategy.storage")) - 1)) & ~bytes32(uint256(0xff));

    struct PrivilegedData {
        mapping(address => bool) privileged;
    }

    function _privilegedStorage() internal pure returns (PrivilegedData storage P) {
        bytes32 slot = PRIVILEGED_STORAGE;
        assembly {
            P.slot := slot
        }
    }

    function _setPrivileged(address _account, bool _status) internal {
        PrivilegedData storage P = _privilegedStorage();
        // Skip SSTORE + event when the flag is already at the requested value.
        // Avoids spurious PrivilegedUpdated logs that would skew off-chain indexer timelines.
        if (P.privileged[_account] == _status) return;
        P.privileged[_account] = _status;
        emit PrivilegedUpdated(_account, _status);
    }

    function _setPrivilegedBatch(address[] calldata _accounts, bool _status) internal {
        PrivilegedData storage P = _privilegedStorage();
        for (uint256 i = 0; i < _accounts.length; i++) {
            // Skip per-entry no-ops so the batch emits only on real changes.
            if (P.privileged[_accounts[i]] == _status) continue;
            P.privileged[_accounts[i]] = _status;
            emit PrivilegedUpdated(_accounts[i], _status);
        }
    }

    /// @notice Checks if an account has privileged status.
    /// @param _account The address to check.
    /// @return True if the account is privileged, false otherwise.
    function isPrivileged(address _account) public view returns (bool) {
        return _privilegedStorage().privileged[_account];
    }
}
