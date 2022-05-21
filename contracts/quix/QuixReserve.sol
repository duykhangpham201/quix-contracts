//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract QuixReserve is Ownable {
    address public vault;
    address[] public allowedTokens;

    constructor(
        address[] memory _allowedTokens
    ) {
        allowedTokens = _allowedTokens;
    }

    function withdraw(address _token, uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 tokenBal = IERC20(_token).balanceOf(address(this));
        require(tokenBal >= _amount, "!balance");

        IERC20(_token).transfer(msg.sender, _amount);
    }

    function setVault(address _vault) public onlyOwner {
        vault = _vault;
    }

    function getTokenBalance() public view returns (uint256[] memory) {
        uint256[] memory tokensBalance;
        uint256 totalBalance = 0;

        for (uint256 i; i < allowedTokens.length; i++) {
            uint256 tokenBal = IERC20(allowedTokens[i]).balanceOf(address(this));
            totalBalance += tokenBal;
            tokensBalance[i] = tokenBal;
        }

        tokensBalance[tokensBalance.length] = totalBalance;

        return tokensBalance;
    }
}