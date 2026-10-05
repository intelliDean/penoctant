/* SPDX-License-Identifier: GPL-3.0 */

pragma solidity ^0.8.23;

interface IUniswapV3Pool {
    function token0() external returns (address);
    function token1() external returns (address);
    function fee() external returns (uint24);

    function increaseObservationCardinalityNext(uint16) external;

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }
    function slot0() external returns (Slot0 memory);
}
