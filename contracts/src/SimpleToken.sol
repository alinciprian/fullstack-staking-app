//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title SimpleToken
 * @author @AlinCip
 * @notice This token is created to test how SimpleStaking contract works
 */
contract SimpleToken is ERC20 {
    address owner;

    constructor() ERC20("SimpleToken", "STK") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}
