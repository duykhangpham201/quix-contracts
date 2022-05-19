//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapRouterETH} from "../interfaces/common/IUniswapRouterETH.sol";
import {IUniswapV2Pair} from "../interfaces/common/IUniswapV2Pair.sol";

import {StrategyManager} from "./StrategyManager.sol";

contract StrategyQuickSwap is StrategyManager {
    using SafeERC20 for IERC20;

    address public native;
    address public output;
    address public want;
    address public lpToken0;
    address public lpToken1;

    address public rewardPool;
    address constant public dragonsLair = address(0xf28164A485B0B2C90639E47b0f377b4a438a16B1);

    address[] public outputToNativeRoute;
    address[] public outputToLp0Route;
    address[] public outputToLp1Route;

    bool public harvestOnDeposit;
    uint256 public lastHarvest;

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address _want,
        address _rewardPool,
        address _vault,
        address _unirouter,
        address _feeRecipient,
        uint256 _fee,
        address[] memory _outputToNativeRoute,
        address[] memory _outputToLp0Route,
        address[] memory _outputToLp1Route
    ) public StrategyManager(
        _unirouter, _vault, _feeRecipient, _fee
    ) {
        want = _want;
        rewardPool = _rewardPool;

        output = _outputToNativeRoute[0];
        native = _outputToNativeRoute[_outputToNativeRoute.length-1];
        outputToNativeRoute = _outputToNativeRoute;

        lpToken0 = IUniswapV2Pair(want).token0();
        outputToLp0Route = _outputToLp0Route;

        lpToken1 = IUniswapV2Pair(want).token1();
        outputToLp1Route = _outputToLp1Route;

        _giveAllowances();
    }

    function _giveAllowances() internal {
        IERC20(want).safeApprove(rewardPool, type(uint256).max);
        IERC20(output).safeApprove(unirouter, type(uint256).max);

        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, type(uint256).max);

        
        IERC20(lpToken1).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, type(uint256).max);
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(rewardPool, 0);
        IERC20(output).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, 0);
    }
}