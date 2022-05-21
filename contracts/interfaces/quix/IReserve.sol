// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IReserve {
    function withdraw(address _token, uint256 _amount) external; 
}
