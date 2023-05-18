// SPDX-License-Identifier: MIT
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
error ProjectNotDeployed();
error grantedBefore();
error NotGranted();

contract Staking is IStaking {

    using SafeERC20 for IERC20;

    uint256 private constant WITHDRAW_COOL_DOWN = 30 days;
    uint256 private minimumStakeAmount;
    Campaign private campaign;
    ClientProposal private clientProposal;
    IERC20 private paymentToken; // USDC

    struct Tier{

        uint8 tierType;
        uint8 tierWeight;
        uint240 tierFee;
    }

    mapping(address => mapping(uint => uint)) public contributions;
    mapping(uint => Tier) public projectTiers;
    mapping(address => bool) public grantedInvestors;

    event Staked(address indexed user, uint256 indexed tierFee, uint256 indexed tierType);
    event Withdrawn(address indexed user, uint256 indexed amount);

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

    function addProjectTier(
        uint _projectId, 
        uint8 _type, 
        uint240 _fee,
        uint8 _weight
    ) 
        external 
        onlyOwner 
    {
        
        if (clientProposal.projectDeploymentTime(_projectId) == 0)
            revert ProjectNotDeployed();

        projectTiers[_projectId].tierType = _type;
        projectTiers[_projectId].tierFee = _fee;
        projectTiers[_projectId].tierWeight = _weight;
        
    }

    function selectTier(uint _projectId) external onlygrantedInvestors {

        if (clientProposal.projectDeploymentTime(_projectId) == 0)
            revert ProjectNotDeployed();

        uint8 _tierType = projectTiers[_projectId].tierType;
        uint240 _tierFee = projectTiers[_projectId].tierFee;

        contributions[msg.sender][_projectId] += _tierFee;
        paymentToken.safeTransferFrom(msg.sender, address(this), _tierFee);
        emit Staked(msg.sender, _tierFee, _tierType);
    }

    function cancel(uint _projectId) external onlygrantedInvestors {

        if(contributions[msg.sender][_projectId] == 0)
            revert NotContributed();

        uint amount = contributions[msg.sender][_projectId];
        paymentToken.safeTransferFrom(address(this), msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
        
    }

    function grantInvestor(address _user) external onlyOwner {

        if (grantedInvestors[_user])
            revert grantedBefore();

        grantedInvestors[_user] = true;
    }

    function revokeInvestor(address _user) external onlyOwner {

        if (!grantedInvestors[_user])
            revert NotGranted();

        delete grantedInvestors[_user];
    }

    function selectWinner(address _user) external onlyOwner {


    }

    

}