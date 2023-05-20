// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStaking {

    event Staked(address indexed user, uint256 indexed tierFee, uint256 indexed tierType);
    event Withdrawn(address indexed user, uint256 indexed amount);

}