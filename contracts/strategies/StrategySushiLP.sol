//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapRouterETH} from "../interfaces/common/IUniswapRouterETH.sol";
import {IUniswapV2Pair} from "../interfaces/common/IUniswapV2Pair.sol";
import {IMiniChefV2} from "../interfaces/sushi/IMiniChefV2.sol";
import {IRewarder} from "../interfaces/sushi/IRewarder.sol";

contract StrategySushiLP {

}