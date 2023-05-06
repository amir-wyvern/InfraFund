// SPDX-License-Identifier: BSD-3-Clause license
pragma solidity 0.8.17;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


error ZeroAddress();
error NotGranted();
error NotWhiteListed();
error AlreadyAuditRequested();
error NotAuditor();
error AlreadyVerified();
error WrongInput()

/// @title ClientProposal
/// @author Matin Rezaii
/// @notice A contract which covers the tasks from the client side of the protocol
///         This contract is the client companies entry point to the protocol which
///         contains a projects different status.
/// @dev This contract inherits from the OpenZeppelin's Ownable and Pausable contracts

contract ClientProposal is Ownable, Pausable {

    uint256 private totalProposal;

    mapping(address => bool) private whiteListed;
    mapping(address => bool) private auditors;
    mapping(uint => ProjectProposal) private projectProposals;

    IERC20 private paymentToken;

    struct ProjectProposal{
        string name;
        string symbol;
        string description;
        address proposer;
        uint projectType;
        bool isVerified;
    }

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
    /// @param name Project proposal name
    /// @param symbol Project proposal symbol
    /// @param description Project proposal description
    /// @param _projectType Type of the proposed project

    function submitProposal(
        string calldata name,
        string calldata symbol,
        string calldata description,
        uint _projectType
    ) 
        external
        onlyWhitelisted(msg.sender)
        whenNotPaused()
    {

        uint proposalId = ++totalProposal;

        ProjectProposal memory _projectProposal;

        _projectProposal.name = name;
        _projectProposal.symbol = symbol;
        _projectProposal.description = description;
        _projectProposal.projectType = _projectType;
        _projectProposal.proposer = msg.sender;

        projectProposals[proposalId] = _projectProposal;
        _requestForAudit(proposalId);
    }

    function verifyProject(uint proposalId) external onlyAuditor(msg.sender) {

        bool verified = projectProposals[proposalId].isVerified;
        if(verified)
            revert AlreadyVerified();
    }

    function createProject() external onlyOwner {

        // initialize the token address
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

    function _requestForAudit(address _address) private view {

        if(projectProposals[_address].isVerified)
            revert AlreadyAuditRequested();
    }


}