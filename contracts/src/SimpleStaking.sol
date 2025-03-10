//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Staking Contract
 * @author AlinCip
 * @notice This contract implements a staking mechanism designed to calculate how much interest a single token aquires over the staking period.
 * The algorithm is ispired by Synthetix.
 */
contract SimpleStaking is ReentrancyGuard {
    ///////////////////
    ///Errors
    ///////////////////
    error SimpleStaking__OnlyOwnerFunction();
    error SimpleStaking__NeedsMoreThanZero();
    error SimpleStaking__TransferFailed();
    error SimpleStaking__NotEnoughBalance();
    error SimpleStaking__CurrentlyZeroReward();

    ///////////////////
    ///State Variables
    ///////////////////
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 private constant PRECISION = 1e18;
    address public owner;
    // the amount of reward per second that is distributed to the entire pool of staked tokens
    uint256 public rewardRate;
    // the total amount of staked tokens help by the contract
    uint256 public totalSupply;
    //last time rewards were distributed
    uint256 lastRewardTimestamp;
    // (reward rate * dt * 1e18)/ totalSupply. It is an accumulator of rewards.
    uint256 rewardPerTokenStored;

    // @dev Amount of staked token for each user
    mapping(address => uint256) public balanceOf;
    // @dev Amount of rewards held by each user. We'll consider Pull over Push principle.Each user will retrieve rewards rather than rewards
    // being sent by the protocol
    mapping(address => uint256) public rewards;
    //used to make sure each user can only withdraw from the point the stake is made
    mapping(address => uint256) rewardPerTokenDebt;

    ///////////////////
    ///Events
    ///////////////////

    event TokenStaked(address indexed user, uint256 amount);
    event TokenWithdrew(address indexed user, uint256 amount);
    event RewardHarvested(address indexed user, uint256 amount);

    ///////////////////
    ///Modifiers
    ///////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert SimpleStaking__OnlyOwnerFunction();
        _;
    }

    /**
     *
     * This modifier is used every time a stake/withdraw is made so that we make sure to keep the database updated for each user.
     * The modifier makes sure the reward distribution is fair. No user can benefit from rewards accumulated in rewardPerTokenStored before
     * his stake was made. rewardPerTokenDebt keeps thack of the reward that was accumulated the moment a stake is made.
     */
    modifier updateRewardPerToken(address _account) {
        rewardPerTokenStored = _rewardPerToken();
        lastRewardTimestamp = block.timestamp;

        if (_account != address(0)) {
            rewards[_account] = _earned(_account);
            rewardPerTokenDebt[_account] = rewardPerTokenStored;
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////

    /**
     *
     * @param _stakingToken The token that will be staked, in this case - STK
     * @param _rewardToken The token given as reward, in this case - dUSDC
     * @param _rewardRate The amount of dUSDC per second that will be distributed to the entire pool of staked STK
     */
    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        owner = msg.sender;
        rewardRate = _rewardRate;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardTimestamp = block.timestamp;
    }

    ///////////////////
    // External
    ///////////////////

    /**
     *
     * @param _amount Amount of tokens that will be transfered for staking.
     *
     */
    function stake(uint256 _amount) external updateRewardPerToken(msg.sender) {
        if (_amount <= 0) revert SimpleStaking__NeedsMoreThanZero();
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert SimpleStaking__TransferFailed();
        emit TokenStaked(msg.sender, _amount);
    }

    /**
     *
     * @param _amount The amount of tokens to be withdrew from the contract.
     * Check-Effects-Interaction pattern is being used to ensure reentrancy resilience
     */
    function withdraw(uint256 _amount) external updateRewardPerToken(msg.sender) {
        if (_amount <= 0) revert SimpleStaking__NeedsMoreThanZero();
        if (_amount > balanceOf[msg.sender]) revert SimpleStaking__NotEnoughBalance();
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        bool success = stakingToken.transfer(msg.sender, _amount);
        if (!success) revert SimpleStaking__TransferFailed();
        emit TokenWithdrew(msg.sender, _amount);
    }

    /**
     * The function lets users harvest their rewards accumulated in the contract.
     * CEI pattern for reetrancy resilience
     */
    function getReward() external updateRewardPerToken(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        if (reward <= 0) revert SimpleStaking__CurrentlyZeroReward();
        rewards[msg.sender] = 0;
        bool success = rewardToken.transfer(msg.sender, reward);
        if (!success) revert SimpleStaking__TransferFailed();
        emit RewardHarvested(msg.sender, reward);
    }

    /**
     *
     * @param _newRewardRate The new reward rate
     * @dev Intended to be used only by the owner of the contract
     */
    function updateRewardRate(uint256 _newRewardRate) external onlyOwner {
        rewardRate = _newRewardRate;
    }

    ///////////////////
    // Internal view
    ///////////////////

    /**
     * Internal function used to calculate the amount of reward for a single token.
     * The entire reward is splitted by the totalSupply
     */
    function _rewardPerToken() internal view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (rewardRate * (block.timestamp - lastRewardTimestamp) * PRECISION) / totalSupply;
    }

    /**
     *
     * @param _account The account we want to compute rewards for
     */
    function _earned(address _account) internal view returns (uint256) {
        return
            ((balanceOf[_account] * (_rewardPerToken() - rewardPerTokenDebt[_account])) / PRECISION) + rewards[_account];
    }

    ///////////////////
    // External view
    ///////////////////

    /**
     * Used to retrieve how much each user have staked
     */
    function getBalanceOfUser(address _user) external view returns (uint256) {
        return balanceOf[_user];
    }

    /**
     * used to retrieve the avalible reward accumulated for rach user
     */
    function getAvalibleReward(address _user) external view returns (uint256) {
        return _earned(_user);
    }
}
