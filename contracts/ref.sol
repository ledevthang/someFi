// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Ref is Ownable {

    uint private constant oneHundredPercent = 10000;
    uint private directCommissionPercentage = 2500;
    uint public etherValue = 1 ether;
    address private defaultReferrer;

    constructor(address _defaultReferrer){
        defaultReferrer =_defaultReferrer;
    }

    struct Account {
        uint profit; // current profit
        uint maxProfit; // maximun profit that can be earned
        // uint packageSize; // package size user invest in
        uint commissionPercentage; // commission percenatage can earned by packageSize
        bool isValid;
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
    function setAccountRefInfo(address referrerAddress, uint _amount) external  {
        (uint maxProfit,uint commissionPercentage) = _getRatePerAmount(_amount);
        if(referrerAddress == address(0)){
            Account storage account = refInfo[msg.sender];
            account.maxProfit = maxProfit;
            account.isValid = true;
            // account.packageSize = _amount;
            account.commissionPercentage = commissionPercentage;
        } else {
            checkIsValidRefAddress(referrerAddress);
            Account storage account = refInfo[msg.sender];
            Account storage referrer = refInfo[referrerAddress];
            if (referrer.left == address(0)){
                referrer.left = msg.sender;
            } else {
                referrer.right = msg.sender;
            }
                account.ref = referrerAddress;
                account.maxProfit = maxProfit;
                account.isValid = true;
                // account.packageSize = _amount;
                account.commissionPercentage = commissionPercentage;
        }
      
        
    }

    function checkIsValidRefAddress(address refAddress) public view{
       Account storage ref = refInfo[refAddress];
        if(!ref.isValid){
            revert InvalidReferrerAddress();
        }
        if(ref.left != address(0) && ref.right != address(0)){
            revert ReferrerHasFull();
        }
    }

    function _getRatePerAmount(uint _amount) public view returns (uint, uint) {
        uint maxProfit = 0;
        uint commissionPercentage = 0;
        if(_amount >= 5000 * etherValue){
            maxProfit = 5000 * 3 * etherValue;
            commissionPercentage = 1000;
        }else if(_amount >= 3000 * etherValue){
            maxProfit = 3000 * 3 * etherValue;
            commissionPercentage = 900;
        }else if(_amount >= 1000 * etherValue){
            maxProfit = 1000 * 3 * etherValue;
            commissionPercentage = 800;
        }else if(_amount >= 500 * etherValue){
            maxProfit = 500 * 3 * etherValue;
            commissionPercentage = 700;
        }else if(_amount >= 100 * etherValue){
            maxProfit = 100 * 3 * etherValue;
            commissionPercentage = 500;
        }

        return(maxProfit, commissionPercentage);
    }

    function setDirectCommissionPercentage(uint _percent) external onlyOwner {
        require(_percent >= 1 && _percent <= 100, "Percent must be between 1 and 100");
        directCommissionPercentage = _percent * 100;
    }

    function _buy(
        address sender,
        address ref,
        uint256 amount
    ) internal {
        if (!refInfo[sender].isValid) {
            setAccountRefInfo(ref, amount);
        } else {
            updateAccountInfoRef(amount);
        }
    }

}
