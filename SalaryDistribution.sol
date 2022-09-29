// SPDX-License-Identifier: MIT

import "./Structs.sol";
import "./MultiSig.sol";
import "./Counters.sol";


pragma solidity ^0.8.7;
/*
    A basic salary distribution contract.Here are the some features of it:

    Every employee can claim own salary without waiting the employer if the distribution time has come.
    One of the employers can distribute all salaries.
    Firing,hiring and salary changing situations are handled by MultiSig contract.In order to execute a proposal,it needs to have at least number of confirmations that have declared in the constructor.
*/

contract SalaryDistribution is MultiSig {

    using Counters for Counters.Counter;

    // I have used OpenZeppelin's Counter library to generate unique employee IDs.
    Counters.Counter public employeeCount;
    
    uint256 public sumOfAllSalaries; 

    // ID to Employee
    mapping(uint256 => Employee) public IDToEmployee;

    event Deposit(address indexed sender, uint amount, uint balance);
    event Fired(uint256 indexed _employeeID);
    event Hired(uint256 indexed _employeeID);
    event SalaryChanged(uint256 indexed _employeeID,uint256 newSalary);
    event ClaimSalary(uint256 indexed _employeeID);

    /* 
        The creator of the contract must be careful about that corresponding salary of the address must be at the same index.

        Salaries are in wei.

        Be careful about _nextDistribution. The funds will be locked until _nextDistribution time has come
    */
    constructor(address[] memory employers, uint256 _numConfirmationsRequired, address[] memory _employeeAddresses, uint256[] memory _employeeSalaries, uint256 _nextDistribution) MultiSig(employers, _numConfirmationsRequired) payable {
        require(_employeeAddresses.length > 0, "Employees required");
        require(_employeeAddresses.length == _employeeSalaries.length, "Must be equal");
        require(_nextDistribution > block.timestamp, "Next distribution must be after");

        employeeCount.increment(); // We use ID 0 when we add a new employee 

        for( uint i = 0; i < _employeeAddresses.length; i++) {
            require(_employeeAddresses[i] != address(0), "Invalid address");

            sumOfAllSalaries += _employeeSalaries[i];

            IDToEmployee[employeeCount.current()] = Employee(employeeCount.current(), _employeeAddresses[i], _employeeSalaries[i], _nextDistribution);

            employeeCount.increment();

        }
        // When the employer deploys this contract, there must be enough fund to distribute all salaries for 1 year.
        // If new employers added ,this fund may not be enough !! 
        require(msg.value >= sumOfAllSalaries * 12 , "Deposit for 1 year salaries");
    }

    
    receive() external payable {
        emit Deposit(msg.sender,msg.value,address(this).balance);
    }

    /* 
        If there are enough confirmations for proposal, it can be executed 
    */
    function executeProposal(uint256 _proposalIndex, uint256 _nextDistribution) external onlyEmployer proposalExists(_proposalIndex) notExecuted(_proposalIndex) {
        Proposal memory proposal = proposals[_proposalIndex];
        require(proposal.numberOfConfirmations >= numConfirmationsRequired, "Not enough confirmations");

        proposals[_proposalIndex].isExecuted = true;

        if(!proposal.isHiring) {
            // If isHiring field in the Proposal is false, it means we are firing an employee
            deleteEmployee(proposal.employeeID);   
        } else {
            // If employeeID field in the Proposal is 0, it means that we are adding new employee
            if(proposal.employeeID == 0) {
                addEmployee(employeeCount.current(), proposal.walletAddress, proposal.salary, _nextDistribution);
            } else { // Else, it means we are changing employee's salary
                changeSalary(proposal.employeeID, proposal.salary);
            }
        }
    }

    function deleteEmployee(uint256 _employeeID) internal {
        delete IDToEmployee[_employeeID];
        emit Fired(_employeeID);
    }

    function addEmployee(uint256 _employeeID, address _employeeAddress, uint256 _employeeSalary, uint256 _nextDistribution) internal {
        IDToEmployee[_employeeID] = Employee(_employeeID,_employeeAddress,_employeeSalary,_nextDistribution);
        employeeCount.increment();
        emit Hired(employeeCount.current() - 1);
    }

    function changeSalary(uint256 _employeeID, uint256 _newSalary) internal {
        IDToEmployee[_employeeID].salary = _newSalary;
        emit SalaryChanged(_employeeID, _newSalary);
    }

    // Every employee can claim own salary if distribution time has come
    function claimSalary(uint256 _employeeID) external {
        Employee memory employee = getEmployee(_employeeID);
        require(employee.walletAddress == msg.sender, "You are not this employee");
        require(block.timestamp >= employee.nextDistribution, "You have claimed");

        IDToEmployee[_employeeID].nextDistribution = employee.nextDistribution + 30 days;
        payable(employee.walletAddress).transfer(employee.salary);

        emit ClaimSalary(_employeeID);       
    }

    // One of the employers can distribute salaries
    function distributeSalaries(uint256[] calldata _employeeIDs) external onlyEmployer {
        for( uint256 i = 0; i < _employeeIDs.length ; i++) {
           Employee memory employee = getEmployee(_employeeIDs[i]);
           require(employee.nextDistribution >= block.timestamp);

            IDToEmployee[_employeeIDs[i]].nextDistribution += 30 days;
           payable(employee.walletAddress).transfer(employee.salary);
           
           emit ClaimSalary(_employeeIDs[i]); 
        }
    }

   function getEmployee(uint256 _employeeID) public view returns(Employee memory) {
        return IDToEmployee[_employeeID];
   }


}