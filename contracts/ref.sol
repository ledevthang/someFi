// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Ref is Ownable {

    uint private constant oneHundredPercent = 10000;
    uint private directCommissionPercentage = 2500;
    uint public etherValue = 1 ether;
    address public defaultReferrer;

    // constructor(address _defaultReferrer){
    //     defaultReferrer =_defaultReferrer;
    // }

    struct Account {
        uint profit; // current profit
        uint maxProfit; // maximun profit that can be earned
        uint packageSize; // package size user invest in
        uint branchInvestment; // total branch investment of this account
        uint commissionPercentage; // commission percenatage can earned by packageSize
        bool isCanBeRef;
        address ref; // address of referrer
        address left; // address of child left
        address right; // address of child right
    }
    mapping(address => Account) public refInfo;

    /// Invalid referrer address
    error InvalidReferrerAddress();
    
    /// Referrer has enough members
    error ReferrerHasFull();

    // if root, FE send 0x00...
    function setAccountRefInfo(address referrerAddress,address _sender, uint _amount) public  {
        (uint maxProfit,uint commissionPercentage, uint packageSize) = _getRatePerAmount(_amount);
        Account storage account = refInfo[_sender];
        account.maxProfit = maxProfit;
        account.isCanBeRef = true;
        account.packageSize = packageSize;
        account.commissionPercentage = commissionPercentage;
        account.branchInvestment += packageSize; // update branch invesment
        // check if ref of this account not root
        if (referrerAddress != address(0)) {
            checkIsValidRefAddress(referrerAddress); // check if ref is valid (bought)
            account.ref = referrerAddress;
            Account storage referrer = refInfo[referrerAddress];
            referrer.branchInvestment += packageSize; // update branch invesment of referrer
            if (referrer.left == address(0)){
                referrer.left = _sender;
            } else {
                referrer.right = _sender;
                // account.ref = referrerAddress; // set ref of this account
                // if (_sender == referrer.right) { // earn directCommission
                if (packageSize > refInfo[referrer.left].packageSize) { // check if weak branch is left => update ref profit = left
                    referrer.profit += (refInfo[referrer.left].packageSize * directCommissionPercentage) / oneHundredPercent;
                } else { // check if weak branch is right => update ref profit = right
                    referrer.profit += (packageSize * directCommissionPercentage) / oneHundredPercent;
                }
                updateSenderSRef(_sender);
            // }
            }
        }
      
    }
  
    function updateAccountRefInfo(address _sender, uint _amount) public {
        (uint maxProfit, uint commissionPercentage, uint packageSize) = _getRatePerAmount(_amount);
        Account storage account = refInfo[_sender];
        account.maxProfit += maxProfit;
        account.branchInvestment += packageSize; // update branch invesment
        if(commissionPercentage > account.commissionPercentage){
            account.commissionPercentage = commissionPercentage;
            account.packageSize = packageSize;
        }
    }

    function checkIsValidRefAddress(address refAddress) public view{
       Account storage ref = refInfo[refAddress];
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
        uint packageSize = 0;
        if(_amount >= 5000 * etherValue){
            maxProfit = 5000 * 3 * etherValue;
            commissionPercentage = 1000;
            packageSize = 5000 * etherValue;
        }else if(_amount >= 3000 * etherValue){
            maxProfit = 3000 * 3 * etherValue;
            commissionPercentage = 900;
            packageSize = 3000 * etherValue;
        }else if(_amount >= 1000 * etherValue){
            maxProfit = 1000 * 3 * etherValue;
            commissionPercentage = 800;
            packageSize = 1000 * etherValue;
        }else if(_amount >= 500 * etherValue){
            maxProfit = 500 * 3 * etherValue;
            commissionPercentage = 700;
            packageSize = 500 * etherValue;
        }else if(_amount >= 100 * etherValue){
            maxProfit = 100 * 3 * etherValue;
            commissionPercentage = 500;
            packageSize = 100 * etherValue;
        }

        return(maxProfit, commissionPercentage, packageSize);
    }

    function setDirectCommissionPercentage(uint _percent) external onlyOwner {
        require(_percent >= 1 && _percent <= 100, "Percent must be between 1 and 100");
        directCommissionPercentage = _percent * 100;
    }
    function updateSenderSRef (address sender) public returns  (uint) {
        Account storage currentAddress = refInfo[sender]; // create currentAdress
        uint countRefLevel = 0;
        while (currentAddress.ref != address(0)) { // check if currentAddress have ref
            countRefLevel++;
            Account storage referrer = refInfo[currentAddress.ref]; // create referrer
            // COMPARE WITH OPPOSITE TO UPDATE REFERRER'S PROFIT
            if (currentAddress.ref == referrer.left) { // check if currentAddress is left
                if (referrer.right != address(0)) { // check if referrer have right else NOT RECEIVE COMMISSION PERCENTAGE
                    Account storage right = refInfo[referrer.right]; // create right
                    // EARN COMMISSION PERCENTAGE
                    if (currentAddress.branchInvestment > right.branchInvestment) { // check weak branch is right
                        referrer.profit += (right.branchInvestment * referrer.commissionPercentage) / oneHundredPercent;
                    } else { // check weak branch is current
                        referrer.profit += (currentAddress.branchInvestment * referrer.commissionPercentage) / oneHundredPercent;
                    }
                }
            } else { // check if currentAddress is right
                Account storage left = refInfo[referrer.left]; // create left
                // EARN COMMISSION PERCENTAGE
                if (currentAddress.branchInvestment > left.branchInvestment) { // check weak branch is left
                    referrer.profit += (left.branchInvestment * referrer.commissionPercentage) / oneHundredPercent;
                } else { // check weak branch is current
                    referrer.profit += (currentAddress.branchInvestment * referrer.commissionPercentage) / oneHundredPercent;
                }
            }
            // condition to continue while loop => set currentAddress = it's ref
            currentAddress = refInfo[currentAddress.ref];
        }
        return countRefLevel;
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
