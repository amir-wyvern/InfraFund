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
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Derivatives/CharityToken.sol";
import "./Derivatives/EquityToken.sol";
// import "./Derivatives/PreSaleToken.sol";
// import "./Derivatives/LoanToken.sol";


error ZeroAddress();
error NotGranted();
error NotWhiteListed();
error AlreadyAuditRequested();
error NotAuditor();
error AlreadyVerified();
error WrongInput();
error ProposalNotVerified();
error ProposalFeeRepaid();
error WrongProjectType();
error Max50CharactersAreAllowed();

/// @title ClientProposal
/// @author InfraFund Labs
/// @notice A contract which covers the tasks from the client side of the protocol
///         This contract is the client companies entry point to the protocol which
///         contains a projects different status.
/// @dev This contract inherits from the OpenZeppelin's Ownable and Pausable contracts

contract ClientProposal is Ownable, Pausable {

    using SafeERC20 for IERC20;

    CharityToken private charityToken;
    EquityToken private equityToken;
    // PreSaleToken private preSaleToken;
    // LoanToken private loanToken;

    uint256 private totalProposal;
    uint256 private proposalFee;

    mapping(address => bool) private whiteListed;
    mapping(address => bool) private auditors;
    mapping(uint => ProjectProposal) public projectProposals;

    IERC20 private paymentToken; // USDC

    struct ProjectProposal{
        string name;
        string symbol;
        string description;
        address proposer;
        address deployedAddress;
        uint projectType;
        bool isVerified;
        bool isRepayed;
    }

    event ProposalSubmitted(address indexed proposer, uint indexed proposalId);
    event ProposalVerified(address indexed auditor, uint indexed proposalId);
    event TokenCreated(address indexed clone, string name, string symbol);

    modifier onlyWhitelisted(address _address) {
        if(!whiteListed[_address])
            revert NotWhiteListed();
        _;
    }

    modifier onlyAuditor(address _address) {
        if(!auditors[_address])
            revert NotAuditor();
        _;
    }

    constructor(address _token, uint _fee) {

        if(_token == address(0) || _fee == 0)
            revert WrongInput();

        paymentToken = IERC20(_token);
        proposalFee = _fee;
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
        uint _projectType
    ) 
        external
        onlyWhitelisted(msg.sender)
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

        _requestForAudit(proposalId);

        emit ProposalSubmitted(msg.sender, proposalId);
    }

    /// @notice This function is called to verify a pending proposal
    /// @dev An authorized auditor can call this function
    /// @param proposalId The unique id of a proposal

    function verifyProposal(uint proposalId) external onlyAuditor(msg.sender) {

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
        if(!verified)
            revert ProposalNotVerified();

        string memory _name = _proposal.name;
        string memory _symbol = _proposal.symbol;
        uint _projectType = _proposal.projectType;
        address _owner = msg.sender;
        
        if(_projectType == 0) {

            address token = address(new CharityToken(_name, _symbol, _owner, paymentToken));
            _proposal.deployedAddress = token;
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