//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StrategyManager is Ownable, Pausable {
    address public unirouter;
    address public vault;
    address public feeRecipient;

    uint256 public fee;
    constructor(
        address _unirouter,
        address _vault,
        address _feeRecipient,
        uint256 _fee
    ) public {
        unirouter = _unirouter;
        vault = _vault;
        feeRecipient = _feeRecipient;
        fee = _fee;
    }

    function setUnirouter(address _unirouter) external onlyOwner {
        unirouter = _unirouter;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }
}