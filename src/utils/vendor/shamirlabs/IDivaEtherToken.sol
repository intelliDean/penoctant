// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { IErrors } from "./IErrors.sol";
import { IERC20Permit } from "./IERC20Permit.sol";

interface IDivaEtherTokenErrors {
    error ErrZeroDeposit();
    error ErrZeroAmount();
    error ErrMinDepositAmount();
}

interface IDivaEtherTokenEvents {
    // Emits when token rebased (total supply and/or total shares were changed)
    event TokenRebased(
        uint256 indexed reportTimestamp,
        uint256 timeElapsed,
        uint256 preTotalShares,
        uint256 preTotalEther,
        uint256 postTotalShares,
        uint256 postTotalEther,
        uint256 sharesMintedAsFees
    );

    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     *
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);
}

interface IDivaEtherToken is IErrors, IDivaEtherTokenErrors, IERC20Permit {
    function burnShares(uint256 shares) external returns (uint256);

    function deposit() external payable returns (uint256);

    function transferSharesFrom(address, address, uint256) external;

    function transferShares(address, uint256) external;

    function depositFor(address) external payable returns (uint256);

    function convertToAssets(uint256) external view returns (uint256);

    function convertToShares(uint256) external view returns (uint256);

    function sharesOf(address) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalShares() external view returns (uint128);

    /// @dev value of totalEther == totalSupply
    function totalEther() external view returns (uint128);
}
