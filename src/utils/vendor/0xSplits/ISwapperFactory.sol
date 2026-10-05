// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { OracleParams } from "./OracleParams.sol";
import { ISwapperImpl } from "./SwapperImpl.sol";
import { IUniV3OracleImpl } from "./IUniV3OracleImpl.sol";

interface ISwapperFactory {
    struct CreateSwapperParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
        OracleParams oracleParams;
        uint32 defaultScaledOfferFactor;
        ISwapperImpl.SetPairScaledOfferFactorParams[] pairScaledOfferFactors;
    }

    event CreateSwapper(ISwapperImpl indexed swapper, ISwapperImpl.InitParams params);

    function createSwapper(CreateSwapperParams calldata params_) external returns (ISwapperImpl swapper);

    function createUniV3Oracle(IUniV3OracleImpl.InitParams calldata params_) external returns (IUniV3OracleImpl);
    function swapperImpl() external returns (ISwapperImpl);
}
