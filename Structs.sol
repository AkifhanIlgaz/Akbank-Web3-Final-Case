// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

struct Employee {
        uint256 employeeID; // Unique ID for each employee
        address walletAddress;
        uint256 salary;
        uint256 nextDistribution;
}

struct Proposal {
        bool isHiring; // true means hiring, false means firing      
        uint256 employeeID; // If it is 0, it means that we are hiring new employee, otherwise we are just changing the salary of the employee
        address walletAddress;
        uint256 salary; 
        uint256 numberOfConfirmations;
        bool isExecuted;
}
