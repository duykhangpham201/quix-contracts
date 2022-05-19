// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "./IGasPrice.sol";

contract GasThrottler {

    bool public shouldGasThrottle = true;

    address public gasPrice;

    constructor(address _gasPrice) {
        gasPrice = _gasPrice;
    }

    modifier gasThrottle() {
        if (shouldGasThrottle && Address.isContract(gasPrice)) {
            require(tx.gasprice <= IGasPrice(gasPrice).maxGasPrice(), "!gas");
        }
        _;
    }
}