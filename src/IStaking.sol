// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStaking {

    struct ContributionDetails{

        uint256 contributionAmount;
        uint96 lastContributionTime;
        address project;
    }

    function invest(uint _proposalId, uint _amount) external virtual;
    function withdraw(uint _proposalId) virtual external;

}