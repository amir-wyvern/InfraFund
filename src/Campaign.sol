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
error NotProposed();
error NotAudited();
error NotGCofStage();
error AlreadyVoted();
error CampaignIsClosed();
error AlreadyRequested();
error AlreadyProposed();
error AlreadyAudited();
error AlreadyWeightInitialized();
error TargetAmountReached();
error VotingNotEnded();
error NotAllowedToVote();
error InsufficientVotes();
error NoNeedToExtraFund();
error WorkFinalTimeNotReached();

contract Campaign is Ownable {

    using SafeERC20 for IERC20;

    uint public ballotId;
    uint constant public VOTING_DURATION = 14 days;

    ClientProposal private clientProposal;
    Staking private staking;

    address[] public proposaljudge;
    
    mapping(address => bool) public auditors;
    mapping(uint => mapping(uint => bool)) private projectRequests;
    mapping(uint => mapping(uint => bool)) private projectInvestigation;
    mapping(uint => mapping(uint => uint)) private ballots;
    mapping(uint => mapping(uint => GCProposal)) public gcProposals;
    mapping(uint => mapping(address => Voter)) public voters;

    struct Voter{
        uint weight;
        bool voted;
        uint vote;   
    }

    struct GCProposal{
        string description;
        uint256 neededFund;
        uint64 proposedTime;
        uint64 votingDuration;
        uint128 voteCount;
    }
 
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

    event GCProposalSubmitted(
        address gc,
        uint indexed projectId,
        uint indexed stage,
        uint indexed ballot
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

    function requestForExtraFund(
        uint _projectId, 
        uint _stage,
        uint _neededFund,
        string calldata _description
    ) 
        external 
        onlyGC(_projectId, _stage) 
    {

        if(_neededFund < clientProposal.projectStageCost(_projectId, _stage))
            revert NoNeedToExtraFund();

        if(gcProposals[_projectId][_stage].proposedTime != 0)
            revert AlreadyProposed();

        gcProposals[_projectId][_stage].description = _description;
        gcProposals[_projectId][_stage].neededFund = _neededFund;
        emit GCProposalSubmitted(msg.sender, _projectId, _stage, ballotId);
        _initializeVoting(_projectId, _stage);
    }

    function _initializeVoting(uint _projectId, uint _stage) private {

        gcProposals[_projectId][_stage].proposedTime = uint64(block.timestamp);
        gcProposals[_projectId][_stage].votingDuration = uint64(VOTING_DURATION);
        ++ballotId;
        ballots[_projectId][_stage] = ballotId;
    }

    function giveRightToVote(address _voter, uint _ballotId) external onlyOwner {

        if(voters[_ballotId][_voter].voted)
            revert AlreadyVoted();

        if(voters[_ballotId][_voter].weight != 0)
            revert AlreadyWeightInitialized();

        voters[_ballotId][_voter].weight = 1;
        proposaljudge.push(_voter);
    }

    function releaseExtraFunds(uint _projectId, uint _stage) external onlyGC(_projectId, _stage) {

        uint64 _startTime = gcProposals[_projectId][_stage].proposedTime;
        uint64 _duration = gcProposals[_projectId][_stage].votingDuration;
        if(_startTime == 0)
            revert NotProposed();

        if(_startTime + _duration < block.timestamp)
            revert VotingNotEnded();
        
        if(!_winningProposal(_projectId, _stage))
            revert InsufficientVotes();

        address tokenAddress = clientProposal.projectDeployedAddress(_projectId);
        address GC = clientProposal.projectStageGC(_projectId, _stage);
        uint cost = gcProposals[_projectId][_stage].neededFund;
        IERC20(tokenAddress).safeTransferFrom(tokenAddress, GC, cost);
        emit FundSentToGC(_projectId, _stage, GC, cost);
    }


    function vote(uint projectId, uint stage) external {

        uint _ballotId = ballots[projectId][stage];
        Voter storage sender = voters[_ballotId][msg.sender];

        if(sender.weight == 0)
            revert NotAllowedToVote();
        
        if(sender.voted)
            revert AlreadyVoted();

        sender.voted = true;
        sender.vote = _ballotId;

        gcProposals[projectId][stage].voteCount += uint128(sender.weight);
    }

    function _winningProposal(
        uint projectId, 
        uint stage
    ) 
        private 
        view
        returns(bool)
    {

        GCProposal storage _proposal = gcProposals[projectId][stage];
        uint voteNumber = _proposal.voteCount;
        uint judgeLength = proposaljudge.length;
        uint division = _divUp(judgeLength, 2);
        if(voteNumber < division)
            revert InsufficientVotes();
        return true;
    }

    function _divUp(uint a, uint b) private pure returns(uint c) {

        if(a % b == 0) {
            c = a / b;
        }
        
        else {
            c = (a / b) + 1;
        }
    }

}