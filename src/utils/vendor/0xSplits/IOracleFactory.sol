// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { IOracle } from "./IOracle.sol";
import { IUniV3OracleImpl } from "./IUniV3OracleImpl.sol";

/// @title Oracle factory interface
interface IOracleFactory {
    function createOracle(bytes calldata data_) external returns (IOracle);
    function createUniV3Oracle(IUniV3OracleImpl.InitParams calldata params_) external returns (IOracle);
}
