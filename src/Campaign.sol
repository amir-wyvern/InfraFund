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

import {ClientProposal} from "./ClientProposal.sol";
import {Staking} from "./Staking.sol";

error NotGranted();
error ZeroAddress();
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
    
    mapping(address => bool) public auditors;
    mapping(uint => mapping(uint => bool)) private projectRequests;
    mapping(uint => mapping(uint => bool)) private projectInvestigation;
    mapping(uint => mapping(uint => bool)) private gcs;
 
    event Invested(
        address indexed investor, 
        uint indexed projectId, 
        uint indexed amount
    );

    event FundRequested(
        uint indexed projectId, 
        uint indexed projectStage,
        address indexed GC 
    );

    event FundSentToGC(
        uint indexed projectId, 
        uint indexed projectStage,
        address indexed GC,
        uint fund
    );

    event AddressSet(
        address indexed campaign,
        address indexed client,
        address indexed staking
    );

    modifier onlyWhiteListed {

        if (!staking.grantedInvestors(msg.sender))
            revert NotGranted();
        _;
    }

    modifier onlyAuditors {

        if (!auditors[msg.sender])
            revert NotAuditor();

        _;
    }

    modifier onlyGC(uint _projectId, uint _stage) {

        if (msg.sender != clientProposal.projectStageGC(_projectId, _stage))
            revert NotGCofStage();
        _;
    }

    function setAddresses(address _client, address _staking) external onlyOwner {

        if(_client == address(0) || _staking == address(0))
            revert WrongInput();

        clientProposal = ClientProposal(_client);
        staking = Staking(_staking);
        emit AddressSet(msg.sender, _client, _staking);
    }


    function invest(
        uint _projectId, 
        address _token,
        uint _amount
    ) 
        external 
        onlyWhiteListed 
    {

        uint _deploymentTime = clientProposal.projectDeploymentTime(_projectId);
        uint _investmentPeriod = clientProposal.projectInvestmentPeriod(_projectId);
        uint _target = clientProposal.projectTargetAmount(_projectId);

        if(block.timestamp > _deploymentTime + _investmentPeriod)
            revert CampaignIsClosed();


        IERC20(_token).safeTransferFrom(msg.sender, _token, _amount);

        uint _currentBalance = IERC20(_token).totalSupply();

        if(_currentBalance >= _target)
            revert TargetAmountReached();

        emit Invested(msg.sender, _projectId, _amount);
        
    }


    function requestForFundRelease(
        uint _projectId, 
        uint _stage
    ) 
        external 
        onlyGC(_projectId, _stage) 
    {

        uint _startTime = clientProposal.projectStageStartTime(_projectId,_stage);
        uint _duration = clientProposal.projectStageDuration(_projectId,_stage);

        if(block.timestamp < _startTime + _duration)
            revert WorkFinalTimeNotReached();

        if(projectRequests[_projectId][_stage])
            revert AlreadyRequested();
        
        projectRequests[_projectId][_stage] = true;
        emit FundRequested(_projectId, _stage, msg.sender);
    }

    function auditProjects(uint _projectId, uint _stage) external onlyAuditors {

        if (projectInvestigation[_projectId][_stage])
            revert AlreadyAudited();

        projectInvestigation[_projectId][_stage] = true;
    }

    function releaseFunds(uint _projectId, uint _stage) external onlyOwner {

        if (!projectInvestigation[_projectId][_stage])
            revert NotAudited();

        address tokenAddress = clientProposal.projectDeployedAddress(_projectId);
        address GC = clientProposal.projectStageGC(_projectId, _stage);
        uint cost = clientProposal.projectStageCost(_projectId, _stage);
        IERC20(tokenAddress).safeTransferFrom(tokenAddress, GC, cost);
        emit FundSentToGC(_projectId, _stage, GC, cost);
    }

    function grantAuditor(address _newAuditor) external onlyOwner {

        if(_newAuditor == address(0))
            revert ZeroAddress();

        auditors[_newAuditor] = true;
    }

    function revokeAuditor(address _auditor) external onlyOwner {

        if(!auditors[_auditor])
            revert NotGranted();

        delete auditors[_auditor];
    }



}