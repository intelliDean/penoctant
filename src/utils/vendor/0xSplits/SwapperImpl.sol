// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IOracle } from "./IOracle.sol";
import { QuotePair, QuoteParams } from "./LibQuotes.sol";

interface ISwapperImpl {
    error Invalid_AmountsToBeneficiary();
    error Invalid_QuoteToken();
    error InsufficientFunds_InContract();
    error InsufficientFunds_FromTrader();

    struct InitParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
        IOracle oracle;
        uint32 defaultScaledOfferFactor;
        SetPairScaledOfferFactorParams[] pairScaledOfferFactors;
    }

    struct SetPairScaledOfferFactorParams {
        QuotePair quotePair;
        uint32 scaledOfferFactor;
    }

    function flash(QuoteParams[] calldata quoteParams_, bytes calldata callbackData_) external returns (uint256);

    function payback() external payable;
    function defaultScaledOfferFactor() external view returns (uint32);
    function oracle() external returns (IOracle);
}
