// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { QuotePair } from "./LibQuotes.sol";

/// @dev This contract uses token = address(0) to refer to ETH.
interface IUniV3OracleImpl {
    struct InitParams {
        address owner;
        bool paused;
        uint32 defaultPeriod;
        SetPairDetailParams[] pairDetails;
    }

    struct SetPairDetailParams {
        QuotePair quotePair;
        PairDetail pairDetail;
    }

    struct PairDetail {
        address pool;
        uint32 period;
    }
}
