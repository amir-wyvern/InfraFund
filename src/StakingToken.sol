// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IStakingToken.sol";
import "./ClientProposal.sol";

error WrongInput();
error BelowMinimumStakeAmount();
error NotContributed();
error CooldownTimeRemaining();

contract Staking is IStaking, Ownable {

    using SafeERC20 for IERC20;

    uint256 private constant WITHDRAW_COOL_DOWN = 30 days;
    uint256 private minimumStakeAmount;
    ClientProposal private clientProposal;
    IERC20 private paymentToken; // USDC

    mapping(address => mapping(uint => ContributionDetails)) public contributions;

    event Contributed(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);

    constructor(address _token, address _client, uint _stakingAmount) {

        if(_token == address(0) || _stakingAmount == 0 || _client == address(0))
            revert WrongInput();

        paymentToken = IERC20(_token);
        clientProposal = ClientProposal(_client);
        minimumStakeAmount = _stakingAmount;
    }

    function invest(uint _proposalId, uint _amount) external override {

        if(amount < minimumStakeAmount)
            revert BelowMinimumStakeAmount();

        address _project = clientProposal.projectProposals[_proposalId].deployedAddress;
        contributions[msg.sender][_proposalId].contributionAmount += amount;
        contributions[msg.sender][_proposalId].lastContributionTime = block.timestamp;
        contributions[msg.sender][_proposalId].project = _project;

        emit Contributed(msg.sender, amount);
        paymentToken.safeTransferFrom(msg.sender, project, amount);
    }

    function withdraw(uint _proposalId) external override {

        uint amount = contributions[msg.sender][_proposalId].contributionAmount;
        if (amount == 0)
            revert NotContributed();

        uint time = contributions[msg.sender][_proposalId].lastContributionTime;
        if (time < block.timestamp + WITHDRAW_COOL_DOWN)
            revert CooldownTimeRemaining();

        address project = contributions[msg.sender][_proposalId].project;
        project.withdraw(amount);
    }

}