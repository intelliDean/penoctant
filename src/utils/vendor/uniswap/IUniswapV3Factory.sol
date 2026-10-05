// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IUniswapV3Factory {
    function getPool(address, address, uint24) external returns (address);
}
