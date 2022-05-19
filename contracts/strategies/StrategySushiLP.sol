//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapRouterETH} from "../interfaces/common/IUniswapRouterETH.sol";
import {IUniswapV2Pair} from "../interfaces/common/IUniswapV2Pair.sol";
import {IMiniChefV2} from "../interfaces/sushi/IMiniChefV2.sol";
import {IRewarder} from "../interfaces/sushi/IRewarder.sol";
import {StrategyManager} from "./StrategyManager.sol";

contract StrategySushiLP is StrategyManager {
    using SafeERC20 for IERC20;

    address public native;
    address public output;
    address public want;
    address public lpToken0;
    address public lpToken1;

    address public chef;
    uint256 public poolId;

    uint256 public lastHarvest;
    bool public harvestOnDeposit;

    address[] public outputToNativeRoute;
    address[] public nativeToOutputRoute;
    address[] public outputToLp0Route;
    address[] public outputToLp1Route;

    event StratHarvest(address indexed harvest, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor (
        address _want,
        uint256 _poolId,
        address _chef,
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
        poolId= _poolId;
        chef = _chef;

        require(_outputToNativeRoute.length >=2, "!route");
        output = _outputToNativeRoute[0];
        native = _outputToNativeRoute[_outputToNativeRoute.length-1];
        outputToNativeRoute = _outputToNativeRoute;

        lpToken0 = IUniswapV2Pair(want).token0();
        require(_outputToLp0Route[0] == output, "first!=output");
        require(_outputToLp0Route[_outputToLp0Route.length-1] == lpToken0, "last!=lpToken0");
        outputToLp0Route = _outputToLp0Route;

        lpToken1 = IUniswapV2Pair(want).token1();
        require(_outputToLp1Route[0] == output, "first!=output");
        require(_outputToLp1Route[_outputToLp1Route.length-1] == lpToken1, "last!=lpToken1");
        outputToLp1Route = _outputToLp1Route;

        nativeToOutputRoute = new address[](_outputToNativeRoute.length);
        for (uint i=0; i<_outputToNativeRoute.length; i++) {
            uint idx = _outputToNativeRoute.length - 1 - i;
            nativeToOutputRoute[i] = outputToNativeRoute[idx];
        }

        _giveAllowances();
    }

    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal > 0) {
            IMiniChefV2(chef).deposit(poolId, wantBal, address(this));
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            IMiniChefV2(chef).withdraw(poolId, _amount - wantBal, address(this));
            wantBal = IERC20(want).balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        IERC20(want).safeTransfer(vault, wantBal);
    }

    function beforeDeposit() external virtual {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function harvest() external virtual {
        _harvest();
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        (uint256 _amount,) = IMiniChefV2(chef).userInfo(poolId, address(this));
        return _amount;
    }

    function _harvest() internal whenNotPaused {
        IMiniChefV2(chef).harvest(poolId, address(this));
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
        uint256 toOutput = IERC20(native).balanceOf(address(this));

        if (toOutput > 0) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(toOutput, 0, nativeToOutputRoute, address(this), block.timestamp);
        }

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

    function panic() public onlyOwner {
        pause();
        IMiniChefV2(chef).emergencyWithdraw(poolId, address(this));
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
        IERC20(want).safeApprove(chef, type(uint256).max);
        IERC20(output).safeApprove(unirouter, type(uint256).max);
        IERC20(native).safeApprove(unirouter, type(uint256).max);

        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, type(uint256).max);

        
        IERC20(lpToken1).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, type(uint256).max);
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(chef, 0);
        IERC20(output).safeApprove(unirouter, 0);
        IERC20(native).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, 0);
    }
}