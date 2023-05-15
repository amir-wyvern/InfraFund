// SPDX-License-Identifier: BSD-3-Clause license
pragma solidity 0.8.17;

/*
 ______             ______                          ________                          __ 
/      |           /      \                        /        |                        /  |
$$$$$$/  _______  /$$$$$$  |______   ______        $$$$$$$$/__    __  _______    ____$$ |
  $$ |  /       \ $$ |_ $$//      \ /      \       $$ |__  /  |  /  |/       \  /    $$ |
  $$ |  $$$$$$$  |$$   |  /$$$$$$  |$$$$$$  |      $$    | $$ |  $$ |$$$$$$$  |/$$$$$$$ |
  $$ |  $$ |  $$ |$$$$/   $$ |  $$/ /    $$ |      $$$$$/  $$ |  $$ |$$ |  $$ |$$ |  $$ |
 _$$ |_ $$ |  $$ |$$ |    $$ |     /$$$$$$$ |      $$ |    $$ \__$$ |$$ |  $$ |$$ \__$$ |
/ $$   |$$ |  $$ |$$ |    $$ |     $$    $$ |      $$ |    $$    $$/ $$ |  $$ |$$    $$ |
$$$$$$/ $$/   $$/ $$/     $$/       $$$$$$$/       $$/      $$$$$$/  $$/   $$/  $$$$$$$/ 
                                                                                         
*/ 

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ClientProposal.sol";
import "./Staking.sol";

error NotGranted();
error WrongInput();
error NotAuditor();
error NotAudited();
error NotGCofStage();
error CampaignIsClosed();
error AlreadyRequested();
error AlreadyAudited();
error TargetAmountReached();
error WorkFinalTimeNotReached();

contract Campaign is Ownable {

    using SafeERC20 for IERC20;

    ClientProposal private clientProposal;
    Staking private staking;
    
    mapping(address => bool) private auditors;
    mapping(uint => mapping(uint => bool)) private projectRequests;
    mapping(uint => mapping(uint => bool)) private projectInvestigation;
    mapping(uint => mapping(uint => bool)) private gcs;
 
    event Invested(address indexed investor, uint indexed amount);
    event FundRequested(
        address indexed GC, 
        uint indexed projectId, 
        uint indexed projectStage);

    modifier onlyWhiteListed {

        if (!staking.whiteListed[msg.sender])
            revert NotGranted();
        _;
    }

    modifier onlyAuditors {

        if (!auditors[msg.sender])
            revert NotAuditor();
    }

    modifier onlyGC(uint _projectId, uint _stage) {

        if (msg.sender != clientProposal.projectProps[_projectId, _stage].stageGC)
            revert NotGCofStage();
        _;
    }

    constructor(address _client, address _staking) {

        if(_client == address(0) || _staking == address(0))
            revert WrongInput();

        clientProposal = ClientProposal(_client);
        staking = Staking(_staking);
    }


    function invest(
        uint _proposalId, 
        address _token,
        uint _amount
    ) 
        external 
        onlyWhiteListed 
    {

        uint _deploymentTime = clientProposal.projectProposals[_proposalId].deploymentTime;
        uint _investmentPeriod = clientProposal.projectProposals[_proposalId].investmentPeriod;
        uint _target = clientProposal.projectProposals[_proposalId].targetAmount;

        if(block.timestamp > _deploymentTime + _investmentPeriod)
            revert CampaignIsClosed();


        IERC20(_token).safeTransferFrom(msg.sender, _token, _amount);

        uint _currentBalance = IERC20(_token).totalSupply();

        if(_currentBalance >= _target)
            revert TargetAmountReached();

        emit Invested(msg.sender, _amount);
        
    }


    function requestForFundRelease(
        uint _projectId, 
        uint _stage
    ) 
        external 
        onlyGC(_projectId, _stage) 
    {

        uint _startTime = clientProposal.projectProps[_projectId][_stage].stageStartTime;
        uint _duration = clientProposal.projectProps[_projectId][_stage].duration;

        if(block.timestamp < _startTime + _duration)
            revert WorkFinalTimeNotReached();

        if(projectRequests[_projectId][_stage])
            revert AlreadyRequested();
        
        projectRequests[_projectId][_stage] = true;
        emit FundRequested(msg.sender, _projectId, _stage);
    }

    function auditProjects(uint _projectId, uint _stage) external onlyAuditors {

        if (projectInvestigation[_projectId][_stage])
            revert AlreadyAudited();

        projectInvestigation[_projectId][_stage] = true;
    }

    function releaseFunds(uint _projectId, uint _stage) external onlyOwner {

        if (!projectInvestigation[_projectId][_stage])
            revert NotAudited();

        address tokenAddress = clientProposal.projectProposals[_projectId].deployedAddress;
        IERC20(tokenAddress).safeTransferFrom(tokenAddress, )
    }


}