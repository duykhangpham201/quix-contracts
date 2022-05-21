//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapRouterETH} from "../interfaces/common/IUniswapRouterETH.sol";
import {IUniswapV2Pair} from "../interfaces/common/IUniswapV2Pair.sol";
import {IDragonsLair} from "../interfaces/quick/IDragonsLair.sol";
import {IRewardPool} from "../interfaces/common/IRewardPool.sol";
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
    address[] public lpToken1ToLpToken0Route;

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
        address[] memory _outputToLp1Route,
        address[] memory _lpToken1ToLpToken0Route
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

        lpToken1ToLpToken0Route = _lpToken1ToLpToken0Route;

        _giveAllowances();
    }

    function deposit() public whenNotPaused {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            IRewardPool(rewardPool).stake(wantBal);
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = balanceOfWant();

        IRewardPool(rewardPool).withdraw(wantBal);
        
        IUniswapRouterETH(unirouter).removeLiquidity(lpToken0, lpToken1, wantBal, _amount/2, _amount/2, address(this), block.timestamp);
        if(IERC20(lpToken0).balanceOf(address(this)) < _amount) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(_amount/2, 0, lpToken1ToLpToken0Route, address(this), block.timestamp);
        }

        IERC20(want).safeTransfer(lpToken0, _amount);
        deposit();

        emit Withdraw(balanceOf());
    }

    function beforeDeposit() external {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function _harvest() internal whenNotPaused {
        IRewardPool(rewardPool).getReward();
        uint256 lairBal = IERC20(dragonsLair).balanceOf(address(this));
        IDragonsLair(dragonsLair).leave(lairBal);

        uint256 outputBal = IERC20(output).balanceOf(address(this));
        if (outputBal > 0) {
            _chargeFees();
            _addLiquidity();
            uint256 wantHarvested = balanceOfWant();
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested, balanceOf());
        }
    }

    function _chargeFees() internal {
        uint256 toNative = IERC20(output).balanceOf(address(this)) * fee / 1000;
        IUniswapRouterETH(unirouter).swapExactTokensForTokens(toNative, 0, outputToNativeRoute, address(this), block.timestamp);

        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        IERC20(native).safeTransfer(feeRecipient, nativeBal);
    }

    function _addLiquidity() internal {
        uint256 outputHalf = IERC20(output).balanceOf(address(this)) / 2;

        if (lpToken0 != output) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(outputHalf, 0, outputToLp0Route, address(this), block.timestamp);
        }

        if (lpToken1 != output) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(outputHalf, 0, outputToLp1Route, address(this), block.timestamp);
        }

        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        IUniswapRouterETH(unirouter).addLiquidity(lpToken0, lpToken1, lp0Bal, lp1Bal, 1, 1, address(this), block.timestamp);
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        return IRewardPool(rewardPool).balanceOf(address(this));
    }

    function getLpToken0() public view returns (address) {
        return lpToken0;
    }

    function panic() public onlyOwner {
        pause();
        IRewardPool(rewardPool).withdraw(balanceOfPool());
    }

    function pause() public onlyOwner {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyOwner {
        _unpause();

        _giveAllowances();

        deposit();
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