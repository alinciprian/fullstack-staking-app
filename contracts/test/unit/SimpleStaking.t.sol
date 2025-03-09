//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SimpleStaking} from "../../src/SimpleStaking.sol";
import {SimpleToken} from "../../src/SimpleToken.sol";
import {devUSDC} from "../../src/devUSDC.sol";

contract SimpleStakingTest is Test {
    SimpleStaking public simpleStaking;
    SimpleToken public simpleToken;
    devUSDC public dUSDC;

    address public owner = address(1);
    address public user1 = makeAddr("user1");
    uint256 initialSupply = 1000000000 * 10 ** 18;
    uint256 rewardRate = 1e18;
    uint256 stakingAmount = 100 * 10 ** 18;
    uint256 timePassed = 1000 seconds;

    function setUp() public {
        vm.startPrank(owner);

        //deploy simpleToken si dUSDC
        simpleToken = new SimpleToken();
        dUSDC = new devUSDC(initialSupply);

        //deploy staking contract folosind adresele simpleToken si dUSDC
        simpleStaking = new SimpleStaking(address(simpleToken), address(dUSDC), rewardRate);

        //mintez simpleToken catre owner
        //approve pentru simpleStaking care va utiliza simpleToken
        simpleToken.mint(owner, initialSupply);

        dUSDC.transfer(address(simpleStaking), initialSupply);

        vm.stopPrank();
    }

    function testdevUSDCinitialization() public {
        assertEq(dUSDC.owner(), owner);
        assertEq(dUSDC.initialSupply(), initialSupply);
        vm.expectRevert(bytes("only owner can call this function"));
        dUSDC.mint(msg.sender, initialSupply);
    }

    function testInitialization() public view {
        assertEq(address(simpleStaking.rewardToken()), address(dUSDC));
        assertEq(address(simpleStaking.stakingToken()), address(simpleToken));
        assertEq(simpleToken.balanceOf(owner), initialSupply);
        assertEq(dUSDC.balanceOf(address(simpleStaking)), initialSupply);
        assertEq(rewardRate, 1e18);
    }

    function testStakingFunction() public {
        simpleToken.approve(address(simpleStaking), stakingAmount);

        //test if user can deposit 0
        vm.startPrank(owner);
        vm.expectRevert("amount must be greater than 0");
        simpleStaking.stake(0);

        //test if balance and totalSupply updates
        simpleToken.approve(address(simpleStaking), stakingAmount);
        simpleStaking.stake(stakingAmount);
        assertEq(simpleStaking.getBalanceOfUser(owner), stakingAmount);
        assertEq(simpleStaking.totalSupply(), stakingAmount);
    }

    function testWithdrawFunction() public {
        vm.startPrank(owner);
        simpleToken.approve(address(simpleStaking), stakingAmount);
        simpleStaking.stake(stakingAmount);

        //withdraw 0 must revert
        simpleToken.approve(address(simpleStaking), stakingAmount);
        vm.expectRevert("amount must be greater than 0");
        simpleStaking.withdraw(0);

        //cannot withdraw more than user's balance
        simpleToken.approve(address(simpleStaking), stakingAmount);
        vm.expectRevert("not enough balance");
        simpleStaking.withdraw(stakingAmount + 1);

        assertEq(simpleToken.balanceOf(owner), initialSupply - stakingAmount);

        //updates databes after withdraw
        simpleToken.approve(address(simpleStaking), stakingAmount);
        simpleStaking.withdraw(stakingAmount);
        assertEq(simpleStaking.getBalanceOfUser(owner), 0);
        assertEq(simpleStaking.totalSupply(), 0);
        assertEq(simpleToken.balanceOf(owner), initialSupply);
    }

    function testOneUserGetsStakingReward() public {
        vm.startPrank(owner);

        simpleToken.approve(address(simpleStaking), initialSupply);
        simpleStaking.stake(stakingAmount);

        uint256 balanceOfdUSDCBefore = dUSDC.balanceOf(owner);
        vm.warp(block.timestamp + timePassed);
        simpleStaking.getReward();
        uint256 balanceOfdUSDCAfter = dUSDC.balanceOf(owner);
        assertEq(balanceOfdUSDCAfter, balanceOfdUSDCBefore + timePassed * rewardRate);

        vm.stopPrank();
    }

    function testStakingRewardsWorksWithMultipleUsers() public {
        vm.startPrank(owner);
        simpleToken.transfer(user1, stakingAmount);

        simpleToken.approve(address(simpleStaking), initialSupply);
        simpleStaking.stake(stakingAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        simpleToken.approve(address(simpleStaking), initialSupply);
        simpleStaking.stake(stakingAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        vm.prank(owner);
        simpleStaking.getReward();
        vm.prank(user1);
        simpleStaking.getReward();

        assertEq(dUSDC.balanceOf(owner), timePassed * rewardRate / 2);
        assertEq(dUSDC.balanceOf(user1), timePassed * rewardRate / 2);
    }

    function testUpdateRewardRate() public {
        vm.prank(owner);
        simpleStaking.updateRewardRate(2);
        assertEq(simpleStaking.rewardRate(), 2);
    }

    function testGetAvalibleReward() public {
        vm.startPrank(owner);

        simpleToken.approve(address(simpleStaking), initialSupply);
        simpleStaking.stake(stakingAmount);

        vm.warp(block.timestamp + timePassed);

        assertEq(simpleStaking.getAvalibleReward(owner), timePassed * rewardRate);

        simpleStaking.getReward();
        assertEq(simpleStaking.getAvalibleReward(owner), 0);

        assertEq(dUSDC.balanceOf(owner), timePassed * rewardRate);

        vm.stopPrank();
    }
}
