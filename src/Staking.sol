// SPDX-License-Identifier: BSD-3-Clause license
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStaking} from "./IStaking.sol";
import {ClientProposal} from "./ClientProposal.sol";
import {Campaign} from "./Campaign.sol";

error WrongInput();
error BelowMinimumStakeAmount();
error OnlyOwnerCanCall();
error NotContributed();
error CooldownTimeRemaining();
error WrongTier();
error grantedBefore();
error NotGranted();

/// @title Staking contract
/// @author InfraFund Labs
/// @notice Choosing the granted investors to be elligible to invest on projects

contract Staking is IStaking {

    using SafeERC20 for IERC20;

    uint256 private constant WITHDRAW_COOL_DOWN = 30 days;
    uint256 private minimumStakeAmount;
    Campaign private campaign;
    ClientProposal private clientProposal;
    IERC20 private paymentToken; // USDC

    struct Tier{
        uint128 tierTicket;
        uint128 tierFee;
    }

    struct Contribution{
        uint128 stakedAmount;
        uint128 ticketAmount;
    }

    mapping(address => Contribution) public contributions;
    mapping(uint => Tier) public tiers;
    mapping(address => bool) public grantedInvestors;

    modifier onlyOwner {

        if(msg.sender != campaign.owner())
            revert OnlyOwnerCanCall();

        _;
    }

    modifier onlygrantedInvestors{

        if(!grantedInvestors[msg.sender])
            revert NotGranted();

        _;
    }

    constructor(
        address _token,
        address _client,
        address _campaign, 
        uint _stakingAmount
        )
    {

        if(_token == address(0) || _campaign == address(0) || _client == address(0))
            revert WrongInput();

        paymentToken = IERC20(_token);
        clientProposal = ClientProposal(_client);
        campaign = Campaign(_campaign);
        minimumStakeAmount = _stakingAmount;
    }

    /// @notice Adds investing tiers for investors
    /// @dev only owner can call this function
    /// @param _type the type of the tier
    /// @param _fee the fee of the corresponding tier
    /// @param _ticketAmount number of the tickets
    function addTier(
        uint8 _type, 
        uint128 _fee,
        uint128 _ticketAmount
    ) 
        external 
        onlyOwner 
    {

        tiers[_type].tierFee = _fee;
        tiers[_type].tierTicket = _ticketAmount;      
    }

    /// @notice Investor selects one of the tier programs
    /// @dev Reverts if the tier type is wrong
    /// @param _tierType the type of the tier
    function selectTier(uint _tierType) external {

        if (tiers[_tierType].tierFee == 0)
            revert WrongTier();

        uint128 amount = tiers[_tierType].tierTicket;
        uint128 fee = tiers[_tierType].tierFee;

        contributions[msg.sender].stakedAmount += fee;
        contributions[msg.sender].ticketAmount += amount;

        paymentToken.safeTransferFrom(msg.sender, address(this), fee);
        emit Staked(msg.sender, fee, _tierType);
    }

    /// @notice User withdraws his/her assets
    /// @dev Callable externally
    function cancel() external {

        uint staked = contributions[msg.sender].stakedAmount;
        if(staked == 0)
            revert NotContributed();

        uint amount = staked;
        delete contributions[msg.sender];

        paymentToken.safeTransferFrom(address(this), msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Grants an investor manually
    /// @dev only owner can call
    function grantInvestor(address _user) external onlyOwner {

        if (grantedInvestors[_user])
            revert grantedBefore();

        grantedInvestors[_user] = true;
    }

    /// @notice Revokes the permission of an investor
    /// @dev only owner can call
    function revokeInvestor(address _user) external onlyOwner {

        if (!grantedInvestors[_user])
            revert NotGranted();

        delete grantedInvestors[_user];
    }

    // function selectWinner(address _user) external onlyOwner {


    // }

}