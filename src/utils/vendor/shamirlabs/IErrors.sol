// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

interface IErrors {
    error ZeroAddress();
    error ZeroAmount();
    error AccessDenied();
    error InvalidSignature();
    error OnlyValidatorManager();
    // Operator fee higher than 10%
    error ErrorHighOperatorFee();
}
