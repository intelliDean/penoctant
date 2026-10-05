// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { YieldForwarder } from "src/core/YieldForwarder.sol";

/**
 * @title YieldForwarder Factory
 * @author [Golem Foundation](https://golem.foundation)
 * @custom:security-contact security@golem.foundation
 * @notice Factory for deploying YieldForwarder instances via CREATE2
 * @dev Uses full CREATE2 deployment (not proxy) since the contract is tiny.
 *
 *      DEPLOYMENT PATTERN:
 *      - Full bytecode deployment via CREATE2 for deterministic addresses
 *      - Salt includes receiver, keeper, caller-provided salt, and deployer for uniqueness
 *      - Each deployment tracked per deployer
 *
 *      FEATURES:
 *      - Deterministic addresses via CREATE2
 *      - Deployment tracking per deployer
 *      - Address prediction for governance proposals
 */
contract YieldForwarderFactory {
    // ============================================
    // STRUCTS
    // ============================================

    /**
     * @notice Information about a deployed yield forwarder
     * @dev Stored for each deployer to track their forwarders
     */
    struct ForwarderInfo {
        /// @notice Address of the deployed forwarder contract
        address forwarderAddress;
        /// @notice Address of the receiver configured in the forwarder
        address receiver;
        /// @notice Address of the keeper configured in the forwarder
        address keeper;
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Mapping of deployers to their deployed forwarders
    /// @dev Allows tracking and enumeration of forwarders per deployer
    mapping(address => ForwarderInfo[]) public deployerToForwarders;

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a new YieldForwarder is created
    /// @param deployer Address that deployed the forwarder
    /// @param forwarderAddress Address of the deployed forwarder
    /// @param salt Caller-provided salt used for CREATE2
    /// @param receiver Address configured as the forwarder's receiver
    /// @param keeper Address configured as the forwarder's keeper
    event YieldForwarderCreated(
        address indexed deployer,
        address indexed forwarderAddress,
        bytes32 indexed salt,
        address receiver,
        address keeper
    );

    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when a forwarder already exists at the predicted address
    error ForwarderAlreadyExists(address existingForwarder);

    // ============================================
    // EXTERNAL FUNCTIONS
    // ============================================

    /**
     * @notice Creates a new YieldForwarder instance with deterministic address
     * @dev Uses CREATE2 with a salt derived from receiver, keeper, caller-provided salt, and msg.sender.
     *      This allows governance proposals to use a fixed salt, avoiding race conditions.
     * @param _receiver Address that will receive forwarded assets
     * @param _keeper Address authorized to call reportAndForward on the forwarder
     * @param _salt Caller-provided salt for deterministic address
     * @return forwarder Address of newly created YieldForwarder
     */
    function createYieldForwarder(
        address _receiver,
        address _keeper,
        bytes32 _salt
    ) external returns (address forwarder) {
        bytes32 finalSalt = _computeFinalSalt(_receiver, _keeper, _salt, msg.sender);
        bytes memory bytecode = _getCreationBytecode(_receiver, _keeper);

        // Check if forwarder already exists at predicted address
        address predicted = Create2.computeAddress(finalSalt, keccak256(bytecode));
        if (predicted.code.length > 0) {
            revert ForwarderAlreadyExists(predicted);
        }

        forwarder = Create2.deploy(0, finalSalt, bytecode);

        // Track deployment
        deployerToForwarders[msg.sender].push(ForwarderInfo(forwarder, _receiver, _keeper));

        emit YieldForwarderCreated(msg.sender, forwarder, _salt, _receiver, _keeper);
    }

    /**
     * @notice Predicts the deterministic address where a YieldForwarder will be deployed
     * @dev Uses CREATE2 address computation with the same salt derivation as createYieldForwarder
     * @param _receiver Address that will be the forwarder's receiver
     * @param _keeper Address that will be the forwarder's keeper
     * @param _salt The same salt that will be passed to createYieldForwarder
     * @param _deployer Address that will call createYieldForwarder
     * @return predicted Predicted address of deployment
     */
    function computeYieldForwarderAddress(
        address _receiver,
        address _keeper,
        bytes32 _salt,
        address _deployer
    ) external view returns (address predicted) {
        bytes32 finalSalt = _computeFinalSalt(_receiver, _keeper, _salt, _deployer);
        bytes memory bytecode = _getCreationBytecode(_receiver, _keeper);
        predicted = Create2.computeAddress(finalSalt, keccak256(bytecode));
    }

    /**
     * @notice Returns all yield forwarders created by a specific deployer
     * @dev May be expensive for deployers with many forwarders
     * @param _deployer Address to query forwarders for
     * @return forwarders Array of deployed forwarders with receiver info
     */
    function getForwardersByDeployer(address _deployer) external view returns (ForwarderInfo[] memory) {
        return deployerToForwarders[_deployer];
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    /**
     * @dev Computes the final CREATE2 salt from receiver, keeper, caller salt, and deployer
     * @param _receiver Forwarder receiver address
     * @param _keeper Forwarder keeper address
     * @param _salt Caller-provided salt
     * @param _deployer Deployer address
     * @return Final salt for CREATE2
     */
    function _computeFinalSalt(
        address _receiver,
        address _keeper,
        bytes32 _salt,
        address _deployer
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(keccak256(abi.encode(_receiver, _keeper, _salt)), _deployer));
    }

    /**
     * @dev Returns the creation bytecode for a YieldForwarder with the given params
     * @param _receiver Receiver address to encode in constructor args
     * @param _keeper Keeper address to encode in constructor args
     * @return Creation bytecode including constructor args
     */
    function _getCreationBytecode(address _receiver, address _keeper) internal pure returns (bytes memory) {
        return abi.encodePacked(type(YieldForwarder).creationCode, abi.encode(_receiver, _keeper));
    }
}
