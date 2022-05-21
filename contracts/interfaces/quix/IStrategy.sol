// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IStrategy {
    function beforeDeposit() external;
    function enter(uint256 _amount) external;
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
    function balanceOfWant() external view returns (uint256);
    function balanceOfPool() external view returns (uint256);
    function harvest() external;
    function panic() external;
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}
