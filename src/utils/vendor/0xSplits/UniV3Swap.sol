// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { ISwapRouter } from "src/utils/vendor/uniswap/ISwapRouter.sol";
import { WETH } from "solady/tokens/WETH.sol";
import { QuoteParams } from "./LibQuotes.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { TokenUtils } from "./TokenUtils.sol";

import { ISwapperFlashCallback } from "./ISwapperFlashCallback.sol";
import { ISwapperImpl } from "./SwapperImpl.sol";
import { ISwapperFactory } from "./ISwapperFactory.sol";

/// @title Uniswap V3 Swapper Integration
/// @author 0xSplits
/// @notice Used by EOAs & simple bots to execute `Swapper#flash` with uniswap v3
/// @dev This contract uses token = address(0) to refer to ETH.
contract UniV3Swap is ISwapperFlashCallback {
    using SafeTransferLib for address;
    using TokenUtils for address;

    struct InitFlashParams {
        QuoteParams[] quoteParams;
        FlashCallbackData flashCallbackData;
    }

    struct FlashCallbackData {
        ISwapRouter.ExactInputParams[] exactInputParams;
        address excessRecipient;
    }

    ISwapperFactory public immutable swapperFactory;
    ISwapRouter public immutable swapRouter;
    WETH public immutable weth9;

    error Unauthorized();
    error InsufficientFunds();

    constructor(ISwapperFactory swapperFactory_, ISwapRouter swapRouter_, WETH weth9_) {
        swapperFactory = swapperFactory_;
        swapRouter = swapRouter_;
        weth9 = weth9_;
    }

    /// receive from weth9
    receive() external payable {}

    /// begin `Swapper#flash`
    /// @dev trader may pay ETH & include the extra WETH in `params_.exactInputParams` to make up
    /// for `Swapper#oracle` shortfall. If swapper incentives are insufficient and they still want to push
    /// funds to `beneficiary`. Recipient in `params_.exactInputParams` should always be _this_ contract
    /// so it can handle the approval / payback for Swapper
    function initFlash(ISwapperImpl swapper, InitFlashParams calldata params_) external payable {
        swapper.flash(params_.quoteParams, abi.encode(params_.flashCallbackData));
    }

    /// `Swapper#flash` callback
    /// @dev by end of function if `tokenToBeneficiary_` is ETH, must have sent `amountToBeneficiary_`
    /// to `Swapper#payback`. Otherwise, must approve Swapper to transfer `amountToBeneficiary_`
    /// DO NOT HOLD FUNDS IN THIS CONTRACT WITHOUT ADDING PROPER VERIFICATION OF MSG.SENDER
    function swapperFlashCallback(
        address tokenToBeneficiary_,
        uint256 amountToBeneficiary_,
        bytes calldata data_
    ) external {
        FlashCallbackData memory flashCallbackData = abi.decode(data_, (FlashCallbackData));
        ISwapRouter.ExactInputParams[] memory exactInputParams = flashCallbackData.exactInputParams;

        uint256 ethBalance = address(this).balance;
        if (ethBalance != 0) {
            weth9.deposit{ value: ethBalance }();
        }

        uint256 totalOut = (tokenToBeneficiary_._isETH())
            ? weth9.balanceOf(address(this))
            : tokenToBeneficiary_.balanceOf(address(this));

        uint256 length = exactInputParams.length;
        for (uint256 i; i < length; ) {
            ISwapRouter.ExactInputParams memory eip = exactInputParams[i];
            address token = _getStartTokenFromPath(eip.path);

            token.safeApprove(address(swapRouter), eip.amountIn);
            totalOut += swapRouter.exactInput(eip);

            unchecked {
                ++i;
            }
        }

        if (totalOut < amountToBeneficiary_) revert InsufficientFunds();

        address excessRecipient = flashCallbackData.excessRecipient;
        if (tokenToBeneficiary_._isETH()) {
            // withdraw WETH from uni swaps to ETH
            uint256 weth9Balance = weth9.balanceOf(address(this));
            weth9.withdraw(weth9Balance);

            // send req'd amt to swapper#payback
            // False positive: totalAmount out is checked before sending
            //slither-disable-next-line arbitrary-send-eth
            ISwapperImpl(msg.sender).payback{ value: amountToBeneficiary_ }();

            // xfr excess out
            ethBalance = address(this).balance;
            if (ethBalance != 0) {
                excessRecipient.safeTransferETH(ethBalance);
            }
        } else {
            // approve swapper to xfr req'd amt out
            tokenToBeneficiary_.safeApprove(msg.sender, amountToBeneficiary_);

            // xfr excess out
            uint256 excessBalance = ERC20(tokenToBeneficiary_).balanceOf(address(this)) - amountToBeneficiary_;
            if (excessBalance > 0) {
                tokenToBeneficiary_.safeTransfer(excessRecipient, excessBalance);
            }
        }
    }

    function _getStartTokenFromPath(bytes memory path) internal pure returns (address token) {
        assembly {
            token := mload(add(path, 0x14))
        }
    }
}
