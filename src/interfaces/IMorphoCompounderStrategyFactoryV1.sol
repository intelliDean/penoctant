// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.25;

/**
 * @title IMorphoCompounderStrategyFactoryV1
 * @notice Interface for V1 MorphoCompounderStrategyFactory deployed on mainnet
 * @dev V1 factory at 0x052d20B0e0b141988bD32772C735085e45F357c1 uses 7-param signature (no _symbol)
 *      Use this interface when interacting with deployed V1 contracts on mainnet forks.
 */
interface IMorphoCompounderStrategyFactoryV1 {
    /// @notice Yearn Strategy USDC vault address
    function YS_USDC() external view returns (address);

    /// @notice USDC token address
    function USDC() external view returns (address);

    /**
     * @notice Deploy a new MorphoCompounder strategy (V1 signature - no symbol param)
     * @param _name Strategy share token name
     * @param _management Management address (can update params)
     * @param _keeper Keeper address (calls report)
     * @param _emergencyAdmin Emergency admin address
     * @param _donationAddress Dragon router address (receives profit shares)
     * @param _enableBurning True to enable burning shares during loss protection
     * @param _tokenizedStrategyAddress TokenizedStrategy implementation address
     * @return strategyAddress Deployed MorphoCompounderStrategy address
     */
    function createStrategy(
        string memory _name,
        address _management,
        address _keeper,
        address _emergencyAdmin,
        address _donationAddress,
        bool _enableBurning,
        address _tokenizedStrategyAddress
    ) external returns (address strategyAddress);

    /**
     * @notice Predict strategy address using CREATE2
     * @param _parameterHash Hash of all strategy parameters
     * @param _deployer Address that will deploy the strategy
     * @param _bytecode Full creation bytecode including constructor args
     * @return predictedAddress The predicted deployment address
     */
    function predictStrategyAddress(
        bytes32 _parameterHash,
        address _deployer,
        bytes memory _bytecode
    ) external view returns (address predictedAddress);
}
