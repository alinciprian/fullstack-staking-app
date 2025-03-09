//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Staking Contract
 * @author AlinCip
 * @notice This contract implements a staking mechanism designed to calculate how much interest a token aquires over a period of time
 */
contract SimpleStaking is ReentrancyGuard {
    error SimpleStaking__NeedsMoreThanZero();

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 private constant PRECISION = 1e18;

    address public owner;
    uint256 public rewardRate;
    // the total amount of staked tokens
    uint256 public totalSupply;
    //last time rewards were distributed
    uint256 lastRewardTimestamp;
    // (reward rate * dt * 1e18)/ totalSupply
    uint256 rewardPerTokenStored;
    // how much did each user stake
    mapping(address => uint256) public balanceOf;
    // rewards to be claimed by each user
    mapping(address => uint256) public rewards;
    //used to make sure each user can only withdraw from the point the stake is made
    mapping(address => uint256) rewardPerTokenDebt;

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        owner = msg.sender;
        rewardRate = _rewardRate;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardTimestamp = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateRewardPerToken(address _account) {
        rewardPerTokenStored = _rewardPerToken();
        lastRewardTimestamp = block.timestamp;

        if (_account != address(0)) {
            rewards[_account] = _earned(_account);
            rewardPerTokenDebt[_account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 _amount) external updateRewardPerToken(msg.sender) {
        require(_amount > 0, "amount must be greater than 0");
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "transfer failed");
    }

    function withdraw(uint256 _amount) external updateRewardPerToken(msg.sender) {
        require(_amount > 0, "amount must be greater than 0");
        require(_amount <= balanceOf[msg.sender], "not enough balance");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        require(stakingToken.transfer(msg.sender, _amount), "transfer failed");
    }

    function _rewardPerToken() internal view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (block.timestamp - lastRewardTimestamp) * PRECISION) / totalSupply;
    }

    function _earned(address _account) internal view returns (uint256) {
        return
            ((balanceOf[_account] * (_rewardPerToken() - rewardPerTokenDebt[_account])) / PRECISION) + rewards[_account];
    }

    function getReward() external updateRewardPerToken(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }

    function updateRewardRate(uint256 _newRewardRate) external onlyOwner {
        rewardRate = _newRewardRate;
    }

    function getBalanceOfUser(address _user) public view returns (uint256) {
        return balanceOf[_user];
    }

    function getAvalibleReward(address _user) public view returns (uint256) {
        return _earned(_user);
    }
}
