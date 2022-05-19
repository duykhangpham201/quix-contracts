// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IDragonsLair {
    function enter(uint256 amount) external;
    function leave(uint256 amount) external;
    function dQUICKForQUICK(uint256 amount) external view returns (uint256);
    function QUICKForDQUICK(uint256 amount) external view returns (uint256);
}
