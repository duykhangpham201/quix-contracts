//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IStrategy} from "../interfaces/quix/IStrategy.sol";
import {IReserve} from "../interfaces/quix/IReserve.sol";

contract QuixVault is ERC20, Ownable, ReentrancyGuard {
    address public reserve;
    address[] public strategies;
    address[] public allowedTokens;
    mapping(address => bool) public allowedTokensMapping;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public rewardsRecorded;

    event Enter(address _user, uint256 _amount);
    event Withdraw(address _user, uint256 _amount);
    event RewardsClaimed(address _user, uint256 _amount);

    modifier updateReward(address _user) {
        lastUpdateTime = block.timestamp;
        rewards[_user] = earned(_user);
        _;
    }

    constructor(
        address _reserve,
        string memory _name,
        string memory _symbol,
        address[] memory _allowedTokens,
        uint256 _rewardRate
    ) public ERC20(_name, _symbol) {
        allowedTokens = _allowedTokens;
        rewardRate = _rewardRate;
        reserve = _reserve;
    }   

    function enter(address _token, uint256 _amount) external updateReward(msg.sender) nonReentrant {
        require(_amount > 0, "!amount");
        require(allowedTokensMapping[_token] == true, "!allowedTokens");

        emit Enter(msg.sender, _amount);

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        uint256 allocatingIndex = _leastAllocated();
        IStrategy(strategies[allocatingIndex]).enter(_amount);
        _mint(msg.sender, _amount);
    }

    function withdraw(address _token, uint256 _amount) external updateReward(msg.sender) nonReentrant {
        require(_amount > 0, "!amount");
        require(allowedTokensMapping[_token] == true, "!allowedTokens");

        uint256 qBalance = IERC20(address(this)).balanceOf(msg.sender);
        require(qBalance >= _amount, "!amount");

        _burn(msg.sender, _amount);
        uint256 allocatingIndex = _mostAllocated();
        IStrategy(strategies[allocatingIndex]).withdraw(_amount);

        emit Withdraw(msg.sender, _amount);

        IERC20(_token).transfer(msg.sender, _amount);
    }

    function addStrategy(address _strategy) external onlyOwner {
        strategies.push(_strategy);
    }

    function retireStrategy(uint256 _index) external onlyOwner {
        strategies[_index] = strategies[strategies.length -1];
        strategies.pop();
    }

    function rewardPerToken() public view returns (uint256) {
        return (block.timestamp - lastUpdateTime) * rewardRate * 1e18;
    }

    function earned(address _user) public view returns (uint256) {
        uint256 qBalance = IERC20(address(this)).balanceOf(_user);

        return qBalance * rewardPerToken(); 
    } 

    function claimReward(uint256 tokenIndex) external updateReward(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        _burn(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
        IReserve(reserve).withdraw(allowedTokens[tokenIndex], reward);

        IERC20(allowedTokens[tokenIndex]).transfer(msg.sender, reward);
    }

    function _leastAllocated() internal view returns (uint256) {
        uint256 minAllocation = type(uint256).max;
        uint256 allocatingIndex = 0;

        for (uint256 i; i <= strategies.length; i ++) {
            uint256 balance = IStrategy(strategies[i]).balanceOf();
            if (balance < minAllocation) {
                minAllocation = balance;
                allocatingIndex = i;
            }
        }

        return allocatingIndex;
    }

    function _mostAllocated() internal view returns (uint256) {
        uint256 maxAllocation = 0;
        uint256 allocatingIndex = 0;

        for (uint256 i; i <= strategies.length; i ++) {
            uint256 balance = IStrategy(strategies[i]).balanceOf();
            if (balance > maxAllocation) {
                maxAllocation = balance;
                allocatingIndex = i;
            }
        }

        return allocatingIndex;
    }


}