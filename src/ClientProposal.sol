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
                                                                                         

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Derivatives/CharityToken.sol";
import "./Derivatives/EquityToken.sol";
import "./Campaign.sol";
// import "./Derivatives/PreSaleToken.sol";
// import "./Derivatives/LoanToken.sol";


error ZeroAddress();
error NotGranted();
error NotWhiteListed();
error AlreadyAuditRequested();
error NotProposer();
error NotAuditor();
error AlreadyVerified();
error WrongInput();
error ProposalNotVerified();
error ProposalFeeRepaid();
error WrongProjectType();
error LengthsNotEqual();
error ProjectNotDefined();
error Max50CharactersAreAllowed();

/// @title ClientProposal
/// @author InfraFund Labs
/// @notice A contract which covers the tasks from the client side of the protocol
///         This contract is the client companies entry point to the protocol which
///         contains a projects different status.
/// @dev This contract inherits from the OpenZeppelin's Ownable and Pausable contracts

contract ClientProposal is Pausable {

    using SafeERC20 for IERC20;

    CharityToken private charityToken;
    EquityToken private equityToken;
    // PreSaleToken private preSaleToken;
    // LoanToken private loanToken;
    Campaign private campaign;

    uint256 private totalProposal;
    uint256 private proposalFee;

    mapping(address => bool) private grantedClients;
    mapping(uint => ProjectProposal) public projectProposals;
    mapping(uint => mapping(uint => ProjectProps)) public projectProps;

    IERC20 private paymentToken; // USDC

    struct ProjectProposal{
        string name;
        string symbol;
        string description;
        address proposer;
        address deployedAddress;
        uint investmentPeriod;
        uint deploymentTime;
        uint projectType;
        uint targetAmount;
        bool isVerified;
        bool isRepayed;
        bool isDefined;
    }

    struct ProjectProps{
        string stageDescription;
        uint stageStartTime;
        uint duration;
        uint stageTotalCost;
        address stageGC;
        bool isVerfied;
    }

    event ProposalSubmitted(address indexed proposer, uint indexed proposalId);
    event ProposalVerified(address indexed auditor, uint indexed proposalId);
    event ProjectDefined(
        address indexed proposer, 
        uint indexed proposalId,
        string description);
    event TokenCreated(address indexed clone, string name, string symbol);

    modifier onlyOwner {

        if(msg.sender != campaign.owner())
            revert OnlyOwnerCanCall();

        _;
    }

    modifier onlyClients {
        if(!grantedClients[msg.sender])
            revert NotWhiteListed();
        _;
    }

    modifier onlyAuditor {
        if(!campaign.auditors[msg.sender])
            revert NotAuditor();
        _;
    }

    constructor(address _token, address _campaign, uint _fee) {

        if(_token == address(0) || _campaign == address(0))
            revert WrongInput();

        paymentToken = IERC20(_token);
        proposalFee = _fee;
        campaign = Campaign(_campaign);
    }

    /// @notice This function is the entry point of the protocol for the clients
    /// @dev Only permissioned clients can call this function
    /// @param _name Project proposal name
    /// @param _symbol Project proposal symbol
    /// @param _description Project proposal description
    /// @param _projectType Type of the proposed project

    function submitProposal(
        string calldata _name,
        string calldata _symbol,
        string calldata _description,
        uint _projectType,
        uint _investmentPeriod,
        uint _targetAmount
    ) 
        external
        onlyClients
        whenNotPaused()
    {

        if (bytes(_description).length > 50)
            revert Max50CharactersAreAllowed();

        uint proposalId = ++totalProposal;
        ProjectProposal storage _projectProposal = projectProposals[proposalId];

        paymentToken.safeTransferFrom(msg.sender, address(this), proposalFee);

        _projectProposal.name = _name;
        _projectProposal.symbol = _symbol;
        _projectProposal.description = _description;
        _projectProposal.projectType = _projectType;
        _projectProposal.proposer = msg.sender;
        _projectProposal.investmentPeriod = _investmentPeriod;
        _projectProposal.targetAmount = _targetAmount;

        _requestForAudit(proposalId);

        emit ProposalSubmitted(msg.sender, proposalId);
    }

    /// @notice This function is called to verify a pending proposal
    /// @dev An authorized auditor can call this function
    /// @param proposalId The unique id of a proposal

    function verifyProposal(uint proposalId) external onlyAuditor {

        bool verified = projectProposals[proposalId].isVerified;
        if(verified)
            revert AlreadyVerified();

        projectProposals[proposalId].isVerified = true;

        emit ProposalVerified(msg.sender, proposalId);

        bool isPayed = projectProposals[proposalId].isRepayed;

        if (isPayed)
            revert ProposalFeeRepaid();

        projectProposals[proposalId].isRepayed = true;
        paymentToken.safeTransferFrom(address(this), msg.sender, proposalFee);
    }

    function repayProposalFee(uint _proposalId) external onlyOwner {

        bool isPayed = projectProposals[_proposalId].isRepayed;

        if (isPayed)
            revert ProposalFeeRepaid();

        projectProposals[_proposalId].isRepayed = true;
        paymentToken.safeTransferFrom(address(this), msg.sender, proposalFee);
    }


    // TODO: Minimal Proxies (ERC1167)
    function createProject(uint proposalId) external onlyOwner returns(address _project) {

        ProjectProposal storage _proposal = projectProposals[proposalId];
        bool verified = _proposal.isVerified;
        bool defined = _proposal.isDefined;
        if(!verified)
            revert ProposalNotVerified();

        if(!defined)
            revert ProjectNotDefined();

        string memory _name = _proposal.name;
        string memory _symbol = _proposal.symbol;
        uint _projectType = _proposal.projectType;
        address _owner = msg.sender;
        
        if(_projectType == 0) {

            address token = address(new CharityToken(_name, _symbol, _owner, paymentToken));
            _proposal.deployedAddress = token;
            _proposal.deploymentTime = block.timestamp;
            emit TokenCreated(token, _name, _symbol);
            _project = token;
        }

        else if(_projectType == 1) {

            address token = address(new EquityToken(_name, _symbol, _owner, paymentToken));
            _proposal.deployedAddress = token;
            emit TokenCreated(token, _name, _symbol);
            _project = token;
            // return _createClone(EquityToken, _owner, _name, _symbol);
        }

        else if(_projectType == 2) {
            // return _createClone(LoanToken, _owner, _name, _symbol);
        }

        else if(_projectType == 3) {
            // return _createClone(PreSaleToken, _owner, _name, _symbol);
        }

        else
            revert WrongProjectType();
    }

    function defineProjectProps(
        uint _projectId,
        uint[] calldata _startTimes,
        uint[] calldata _durations,
        uint[] calldata _costs,
        string[] calldata _descriptions,
        address[] calldata _gc
    )
        external
        onlyClients
    {
        if(projectProposals[_projectId].proposer != msg.sender)
            revert NotProposer();

        uint _length = _startTimes.length;
        if(_length != _durations.length || _length != _costs.length
            || _length != _descriptions.length || _length != _gc.length)
            revert LengthsNotEqual();

        for (uint i; i < _length;) {

            projectProps[_projectId][i].stageStartTime = _startTimes[i];
            projectProps[_projectId][i].duration = _duration[i];
            projectProps[_projectId][i].stageTotalCost = _costs[i];
            projectProps[_projectId][i].stageDescription = _descriptions[i];
            projectProps[_projectId][i].stageGC = _gc[i];

            unchecked {
                ++i;
            }
        }

        projectProposals[_projectId].isDefined = true;
        emit ProjectDefined(msg.sender, _projectId, description);
    }

    function pause() external onlyOwner {

        _pause();
    }

    function unpause() external onlyOwner {

        _unpause();
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

    function grantProposer(address _newAddress) external onlyOwner {

        if(_newAddress == address(0))
            revert ZeroAddress();

        whiteListed[_newAddress] = true;
    }

    function revokeProposer(address _proposer) external onlyOwner {

        if(!whiteListed[_proposer])
            revert NotGranted();

        delete whiteListed[_proposer];
    }

    function changeTokenAddress(address _newToken) external onlyOwner {

        if(_newToken == address(0))
            revert ZeroAddress();

        paymentToken = IERC20(_newToken);
    }

    function updateInvestmentPeriod(
        uint _proposalId,
        uint _newTime
    )
        external
        onlyOwner
    {

        ProjectProposal storage _projectProposal = projectProposals[proposalId];

        uint period = _projectProposal.deploymentTime;

        if (period > _newTime)
            revert LessInvestmentPeriod();

        _projectProposal.deploymentTime = _newTime;
    }

    function changeProposalFee(uint _fee) external onlyOwner {

        if(_fee == 0)
            revert WrongInput();

        proposalFee = _fee;
    }

    function _requestForAudit(uint _proposalId) private view {

        if(projectProposals[_proposalId].isVerified)
            revert AlreadyAuditRequested();
    }


}