// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IStakingToken.sol";
contract EquityToken is IStakingToken, ERC20, Ownable {

    uint256 constant private INITIAL_SUPPLY = 100_000e18;
    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);

    constructor() ERC20("Equity Token", "EQT") {
        
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}