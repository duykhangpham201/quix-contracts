//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapRouterETH} from "../interfaces/common/IUniswapRouterETH.sol";
import {IUniswapV2Pair} from "../interfaces/common/IUniswapV2Pair.sol";
import {IRewardPool} from "../interfaces/common/IRewardPool.sol";
import {ICurveSwap} from "../interfaces/curve/ICurveSwap.sol";
import {IGaugeFactory} from "../interfaces/curve/IGaugeFactory.sol";
import {IRewardsGauge} from "../interfaces/curve/IRewardsGauge.sol";
import {StrategyManager} from "./StrategyManager.sol";
import {IWrappedNative} from "../interfaces/common/IWrappedNative.sol";
import {GasThrottler} from "./utils/GasThrottler.sol";

contract StrategyCurve is StrategyManager, GasThrottler {
    using SafeERC20 for IERC20;

    address public want;
    address public crv;
    address public native;
    address public depositToken;

    address public gaugeFactory;
    address public rewardsGauge;
    address public pool;
    uint256 public poolSize;
    uint256 public depositIndex;
    bool public useUnderlying;
    bool public useMetapool;

    address[] public crvToNativeRoute;
    address[] public nativeToDepositRoute;

    bool public crvEnabled = true;
    address public crvRouter;

    bool public harvestOnDeposit;
    uint256 public lastHarvest;

    event StratHarvest(address indexed harvester);

    constructor(
        address _want,
        address _gaugeFactory,
        address _gauge,
        address _pool,
        uint256 _poolSize,
        uint256 _depositIndex,
        bool _useUnderlying,
        bool _useMetapool,
        address[] memory _crvToNativeRoute,
        address[] memory _nativeToDepositRoute,
        address _vault,
        address _unirouter,
        address _feeRecipient,
        uint256 _fee,
        address _gasPrice
    ) public StrategyManager(
        _unirouter, _vault, _feeRecipient, _fee
    ) GasThrottler(_gasPrice) {
        want = _want;
        gaugeFactory = _gauge;
        pool = _pool;
        poolSize = _poolSize;
        depositIndex = _depositIndex;
        useUnderlying = _useUnderlying;
        useMetapool = _useMetapool;

        crv = _crvToNativeRoute[0];
        native = _crvToNativeRoute[_crvToNativeRoute.length-1];
        crvToNativeRoute = _crvToNativeRoute;
        crvRouter = unirouter;

        require(_nativeToDepositRoute[0] == native, "!native");
        depositToken = _nativeToDepositRoute[_nativeToDepositRoute.length-1];
        nativeToDepositRoute = _nativeToDepositRoute;

        if (gaugeFactory != address(0)) {
            harvestOnDeposit = true;
        }

        _giveAllowances();
    }

    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal > 0) {
            IRewardsGauge(rewardsGauge).deposit(wantBal);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            IRewardsGauge(rewardsGauge).withdraw(_amount - wantBal);
            wantBal = IERC20(want).balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        IERC20(want).safeTransfer(vault, wantBal);
    }

    function beforeDeposit() external {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function _harvest() internal {
        if (gaugeFactory != address(0)) {
            IGaugeFactory(gaugeFactory).mint(rewardsGauge);
        }
        IRewardsGauge(rewardsGauge).claim_rewards(address(this));
        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        if (nativeBal > 0 || crvBal > 0) {
            _chargeFees();
            _addLiquidity();
            deposit();
            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender);
        }
    }

    function _chargeFees() internal {
        uint256 crvBal = IERC20(crv).balanceOf(address(this));
        if (crvEnabled && crvBal > 0) {
            IUniswapRouterETH(crvRouter).swapExactTokensForTokens(crvBal, 0, crvToNativeRoute, address(this), block.timestamp);
        }

        uint256 nativeBal = IERC20(native).balanceOf(address(this)) * fee / 1000;
        IERC20(native).safeTransfer(feeRecipient, nativeBal);
    }

    function _addLiquidity() internal {
        uint256 depositBal;
        uint256 depositNativeAmount;
        uint256 nativeBal = IERC20(native).balanceOf(address(this));
        if (depositToken != native) {
            IUniswapRouterETH(unirouter).swapExactTokensForTokens(nativeBal, 0, nativeToDepositRoute, address(this), block.timestamp);
            depositBal = IERC20(depositToken).balanceOf(address(this));
        } else {
            depositBal = nativeBal;
            depositNativeAmount = nativeBal;
            IWrappedNative(native).withdraw(depositNativeAmount);
        }

        if (poolSize == 2) {
            uint256[2] memory amounts;
            amounts[depositIndex] = depositBal;
            if (useUnderlying) ICurveSwap(pool).add_liquidity(amounts, 0, true);
            else ICurveSwap(pool).add_liquidity{value: depositNativeAmount}(amounts, 0);
        } else if (poolSize == 3) {
            uint256[3] memory amounts;
            amounts[depositIndex] = depositBal;
            if (useUnderlying) ICurveSwap(pool).add_liquidity(amounts, 0, true);
            else if (useMetapool) ICurveSwap(pool).add_liquidity(want, amounts, 0);
            else ICurveSwap(pool).add_liquidity(amounts, 0);
        } else if (poolSize == 4) {
            uint256[4] memory amounts;
            amounts[depositIndex] = depositBal;
            if (useMetapool) ICurveSwap(pool).add_liquidity(want, amounts, 0);
            else ICurveSwap(pool).add_liquidity(amounts, 0);
        } else if (poolSize == 5) {
            uint256[5] memory amounts;
            amounts[depositIndex] = depositBal;
            ICurveSwap(pool).add_liquidity(amounts, 0);
        }
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        return IRewardsGauge(rewardsGauge).balanceOf(address(this));
    }

    function setCrvEnabled(bool _enabled) external onlyOwner {
        crvEnabled = _enabled;
    }

    function setCrvRoute(address _router, address[] memory _crvToNative) external onlyOwner {
        require(_crvToNative[0] == crv, "!crv");
        require(_crvToNative[_crvToNative.length - 1] == native, "!native");

        _removeAllowances();
        crvToNativeRoute = _crvToNative;
        crvRouter = _router;
        _giveAllowances();
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyOwner {
        harvestOnDeposit = _harvestOnDeposit;
    }

       function setShouldGasThrottle(bool _shouldGasThrottle) external onlyOwner {
        shouldGasThrottle = _shouldGasThrottle;
    }

    function panic() public onlyOwner {
        pause();
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());
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
        IERC20(want).safeApprove(rewardsGauge, type(uint).max);
        IERC20(native).safeApprove(unirouter, type(uint).max);
        IERC20(crv).safeApprove(crvRouter, type(uint).max);
        IERC20(depositToken).safeApprove(pool, type(uint).max);
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(rewardsGauge, 0);
        IERC20(native).safeApprove(unirouter, 0);
        IERC20(crv).safeApprove(crvRouter, 0);
        IERC20(depositToken).safeApprove(pool, 0);
    }
}