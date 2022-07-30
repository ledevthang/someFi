// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Ref is Ownable {

    uint private constant oneHundredPercent = 10000;
    uint private directCommissionPercentage = 2500;
    uint public etherValue = 1 ether;
    address public defaultReferrer;
    uint roundId;

    // constructor(address _defaultReferrer){
    //     defaultReferrer =_defaultReferrer;
    // }

    struct Account {
        uint profit; // current profit
        uint maxProfit; // maximun profit that can be earned
        uint profitClaimed; // profit user claimed
        uint currentPackageSize; // largest package size user invested
        uint totalPackageSize; // total package size user invested
        uint branchInvestment; // total branch investment of this account
        uint commissionPercentage; // commission percenatage can earned by currentPackageSize
        uint totalCommissionProfit; // total commission profit user earned
        bool isCanBeRef;
        address ref; // address of referrer
        address left; // address of child left
        address right; // address of child right
    }
    mapping(address => mapping(uint => Account)) public refInfo;

    /// Invalid referrer address
    error InvalidReferrerAddress();
    
    /// Referrer has enough members
    error ReferrerHasFull();

    function setAccountRefInfo(address referrerAddress,address _sender, uint _amount) public  {
        (uint maxProfit,uint commissionPercentage, uint currentPackageSize) = _getRatePerAmount(_amount);
        Account storage account = refInfo[_sender][roundId];
        account.maxProfit = maxProfit;
        account.isCanBeRef = true;
        account.currentPackageSize = currentPackageSize;
        account.totalPackageSize = currentPackageSize;
        account.commissionPercentage = commissionPercentage;
        account.branchInvestment += currentPackageSize; // update branch invesment
        // check if ref of this account not root
        if (referrerAddress != address(0)) {
            checkIsValidRefAddress(referrerAddress); // check if ref is valid (bought)
            account.ref = referrerAddress;
            Account storage referrer = refInfo[referrerAddress][roundId];
            referrer.branchInvestment += currentPackageSize; // update branch invesment of referrer
            if (referrer.left == address(0)){
                referrer.left = _sender;
            } else {
                referrer.right = _sender;
            }
            updateSenderSRef(_sender);
        }
      
    }
  
    function updateAccountRefInfo(address _sender, uint _amount) public {
        (uint maxProfit, uint commissionPercentage, uint currentPackageSize) = _getRatePerAmount(_amount);
        Account storage account = refInfo[_sender][roundId];
        Account storage referrer = refInfo[account.ref][roundId];
        account.maxProfit += maxProfit;
        account.branchInvestment += currentPackageSize; // update branch invesment
        account.totalPackageSize += currentPackageSize; // update current package size
        referrer.branchInvestment += currentPackageSize; // update referrer investment
        if(commissionPercentage > account.commissionPercentage){
            account.commissionPercentage = commissionPercentage;
            account.currentPackageSize = currentPackageSize;
        }
        // earn directCommission
        if (account.ref != address(0)) {
            updateSenderSRef(_sender);
        }
    }

    function checkIsValidRefAddress(address refAddress) public view{
       Account storage ref = refInfo[refAddress][roundId];
        if(!ref.isCanBeRef){
            revert InvalidReferrerAddress();
        }
        if(ref.left != address(0) && ref.right != address(0)){
            revert ReferrerHasFull();
        }
    }

    function _getRatePerAmount(uint _amount) public view returns (uint, uint, uint) {
        uint maxProfit = 0;
        uint commissionPercentage = 0;
        uint currentPackageSize = 0;
        if(_amount >= 5000 * etherValue){
            maxProfit = 5000 * 3 * etherValue;
            commissionPercentage = 1000;
            currentPackageSize = 5000 * etherValue;
        }else if(_amount >= 3000 * etherValue){
            maxProfit = 3000 * 3 * etherValue;
            commissionPercentage = 900;
            currentPackageSize = 3000 * etherValue;
        }else if(_amount >= 1000 * etherValue){
            maxProfit = 1000 * 3 * etherValue;
            commissionPercentage = 800;
            currentPackageSize = 1000 * etherValue;
        }else if(_amount >= 500 * etherValue){
            maxProfit = 500 * 3 * etherValue;
            commissionPercentage = 700;
            currentPackageSize = 500 * etherValue;
        }else if(_amount >= 100 * etherValue){
            maxProfit = 100 * 3 * etherValue;
            commissionPercentage = 500;
            currentPackageSize = 100 * etherValue;
        }

        return(maxProfit, commissionPercentage, currentPackageSize);
    }

    function setDirectCommissionPercentage(uint _percent) external onlyOwner {
        require(_percent >= 1 && _percent <= 100, "Percent must be between 1 and 100");
        directCommissionPercentage = _percent * 100;
    }
    function updateSenderSRef (address sender) public returns  (uint) {
        Account storage currentAddress = refInfo[sender][roundId]; // create currentAdress
        address _address = sender;
        uint countRefLevel = 0;
        while (currentAddress.ref != address(0) && countRefLevel < 15) { // check if currentAddress have ref
            Account storage referrer = refInfo[currentAddress.ref][roundId]; // create referrer

            referrer.branchInvestment = referrer.totalPackageSize + refInfo[referrer.left][roundId].branchInvestment + refInfo[referrer.right][roundId].branchInvestment;

            // COMPARE WITH OPPOSITE TO UPDATE REFERRER'S PROFIT
            if (_address == referrer.left) { // check if currentAddress is left
                if (referrer.right != address(0)) { // check if referrer have right else NOT RECEIVE COMMISSION PERCENTAGE
                    Account storage right = refInfo[referrer.right][roundId]; // create right
                    // EARN COMMISSION PERCENTAGE
                    if (currentAddress.branchInvestment > right.branchInvestment) { // check weak branch is right
                        // update totalCommisstionProfit
                        referrer.totalCommissionProfit = 
                        ((right.branchInvestment * referrer.commissionPercentage) / oneHundredPercent) +
                        refInfo[referrer.right][roundId].totalCommissionProfit +
                        currentAddress.totalCommissionProfit;

                        referrer.profit = ((right.currentPackageSize * directCommissionPercentage) / oneHundredPercent) + referrer.totalCommissionProfit - referrer.profitClaimed;
                    } else { // check weak branch is current
                        // update totalCommisstionProfit
                        referrer.totalCommissionProfit = 
                        ((currentAddress.branchInvestment * referrer.commissionPercentage) / oneHundredPercent) +
                        currentAddress.totalCommissionProfit +
                        refInfo[referrer.right][roundId].totalCommissionProfit;

                        referrer.profit = ((currentAddress.currentPackageSize * directCommissionPercentage) / oneHundredPercent) + referrer.totalCommissionProfit - referrer.profitClaimed;
                    }
                }
            } else { // check if currentAddress is right
                Account storage left = refInfo[referrer.left][roundId]; // create left
                // EARN COMMISSION PERCENTAGE
                if (currentAddress.branchInvestment > left.branchInvestment) { // check weak branch is left
                    // update totalCommisstionProfit
                    referrer.totalCommissionProfit = 
                    ((left.branchInvestment * referrer.commissionPercentage) / oneHundredPercent) +
                    refInfo[referrer.left][roundId].totalCommissionProfit +
                    currentAddress.totalCommissionProfit;

                    referrer.profit = ((left.currentPackageSize * directCommissionPercentage) / oneHundredPercent) + referrer.totalCommissionProfit - referrer.profitClaimed;
                } else { // check weak branch is current
                    // update totalCommisstionProfit
                    referrer.totalCommissionProfit = 
                    ((currentAddress.branchInvestment * referrer.commissionPercentage) / oneHundredPercent) +
                    currentAddress.totalCommissionProfit +
                    refInfo[referrer.left][roundId].totalCommissionProfit;

                    referrer.profit = ((currentAddress.currentPackageSize * directCommissionPercentage) / oneHundredPercent) + referrer.totalCommissionProfit - referrer.profitClaimed;
                }
            }
            // set new address
            _address = currentAddress.ref;
            // condition to continue while loop => set currentAddress = it's ref
            currentAddress = refInfo[currentAddress.ref][roundId];
            countRefLevel++;
        }
        return countRefLevel;
    }
}

    function _buy(
        address sender,
        address ref,
        uint256 amount
    ) public {
        if (!refInfo[sender].isCanBeRef) {
            setAccountRefInfo(ref, sender, amount );
        } else {
           updateAccountRefInfo(sender, amount);
        }
    }

}
