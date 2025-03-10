//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract devUSDC is ERC20 {
    address public owner;
    uint256 public initialSupply;

    constructor(uint256 _initialSupply) ERC20("devUSDC", "dUSDC") {
        owner = msg.sender;
        initialSupply = _initialSupply;
        _mint(msg.sender, _initialSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
