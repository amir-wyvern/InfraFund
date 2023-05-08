// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ICharityToken.sol";
contract CharityToken is ICharityToken, ERC20 {

    address private owner;

    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);

    function initialize(
        address _owner,
        string calldata __name,
        string calldata __symbol
    )
        external
        initializer
    {
        owner = _owner;
        _name = __name;
        _symbol = __symbol;
    }
}