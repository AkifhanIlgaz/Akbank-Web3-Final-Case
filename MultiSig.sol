// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Structs.sol";

contract MultiSig {

    address[] public employers; 
    mapping(address => bool) public isEmployer;
    uint256 public numConfirmationsRequired;

    // Did the employer confirm proposal
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Array of proposals
    Proposal[] public proposals;

    event SubmitProposal(uint256 indexed proposalIndex);

    event ConfirmProposal(address indexed employer, uint indexed proposalIndex);

    event RevokeConfirmation(address indexed employer, uint indexed proposalIndex);

    event ExecuteProposal(address indexed employer, uint indexed proposalIndex);

     modifier onlyEmployer() {
        require(isEmployer[msg.sender], "You are not an employer");
        _;
    }

    modifier proposalExists(uint _proposalIndex) {
        require( _proposalIndex < proposals.length, " Proposal does not exist");
        _;
    }

    modifier notExecuted(uint _proposalIndex) {
        require( !proposals[_proposalIndex].isExecuted, "Proposal is executed");
        _;
    }

    modifier notConfirmed(uint _proposalIndex) {
        require( !isConfirmed[_proposalIndex][msg.sender], "You have already confirmed");
        _;
    }


    constructor( address[] memory _employers, uint256 _numConfirmationsRequired) {
        require(_employers.length > 0, "Employers required");
        require(_numConfirmationsRequired >= (_employers.length / 2 ) + 1 && _numConfirmationsRequired <= _employers.length, "Invalid number of required confirmations");
   

        for( uint i = 0; i < _employers.length; i++) {
            address employer = _employers[i];

            require(employer != address(0), "Invalid address");
            require(!isEmployer[employer], "Already employer");

            isEmployer[employer] = true;
            employers.push(employer);

        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function submitProposal(bool _isHiring, uint256 _employeeID, address _walletAddress, uint256 _salary) external onlyEmployer {
        uint proposalIndex = proposals.length;

        proposals.push( Proposal({
            isHiring: _isHiring,
            employeeID: _employeeID,
            walletAddress: _walletAddress,
            salary: _salary,
            numberOfConfirmations: 0,
            isExecuted: false
        }));

        emit SubmitProposal(proposalIndex);
    }


    function confirmProposal(uint256 _proposalIndex) external onlyEmployer proposalExists(_proposalIndex) notExecuted(_proposalIndex) notConfirmed(_proposalIndex) {
        Proposal storage proposal = proposals[_proposalIndex];
        proposal.numberOfConfirmations += 1;
        isConfirmed[_proposalIndex][msg.sender] = true;

        emit ConfirmProposal(msg.sender, _proposalIndex);
    }

    function revokeConfirmation(uint256 _proposalIndex) external onlyEmployer proposalExists(_proposalIndex) notExecuted(_proposalIndex) {
        Proposal storage proposal = proposals[_proposalIndex];

        require(isConfirmed[_proposalIndex][msg.sender], "Proposal not confirmed");

        proposal.numberOfConfirmations -= 1;
        isConfirmed[_proposalIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _proposalIndex);
    }

    function getEmployers() public view returns(address[] memory) {
        return employers;
    }

    function getProposalCount() public view returns(uint256) {
        return proposals.length;
    }

    function getProposal(uint _proposalIndex) public view returns(Proposal memory) {
        return proposals[_proposalIndex];
    }

}