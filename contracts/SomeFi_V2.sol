//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract SomeFiV2 is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable,OwnableUpgradeable {
    
    address public operatorAddress;

    uint private oneHundredPercent;
    uint private directCommissionPercentage;
    uint public etherValue;
    IERC20Upgradeable public tokenUSDT;
    uint256 private _totalSupply;
    uint8 private _decimals;
    struct UserInfo {
        uint256 amountICO; 
        uint256 claimAt;
    }
    struct Airdrop {
        address userAddress;
        uint256 amount;
    }

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

    address walletBackup;
    address walletMain;

    // Information of Round
    uint256 public roundId;
    uint256 public totalAmount;
    uint256 public startTimeICO;
    bool public icoHasEnded;
    uint256 public ratePerUSDT;

    mapping(uint256 => uint256) private _amountSoldByRound;

    mapping(address => mapping(uint256 => UserInfo)) public users;

    mapping(address => mapping(uint256 => Account)) public refInfo;


    mapping(address => bool) public blacklist;

    /// Invalid referrer address
    error InvalidReferrerAddress();
    
    /// Referrer has enough members
    error ReferrerHasFull();

    event buyIco(address buyer, uint amount);

    // ⚪ Modifiers
    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "not-operator");
        _;
        
    }

    function buyICOByUSDT(  address ref,uint256 amount)
        external
    {
        address sender = _msgSender();
          _precheckBuy(sender);
        if (!refInfo[sender][roundId].isCanBeRef) {
            setAccountRefInfo(ref, sender, amount );
        } else {
           updateAccountRefInfo(sender, amount);
        }

        uint256 buyAmountToken = amount * ratePerUSDT;

        tokenUSDT.transferFrom(sender, address(this), amount);
        _buy(sender, buyAmountToken, amount);
        emit buyIco(sender, amount);
    }

      function _buy(
        address sender,
        uint buyAmountToken,
        uint amountUsdt
    ) internal {
        uint half = amountUsdt / 2;
        users[sender][roundId].amountICO += buyAmountToken;
        // update total sold by round
        _amountSoldByRound[roundId] += buyAmountToken;
        _mint(sender, buyAmountToken);

        tokenUSDT.transfer(walletBackup, half);
        tokenUSDT.transfer(walletMain, half);

    }

        function _precheckBuy(address sender) internal view {
        require(block.timestamp >= startTimeICO, "ICO time does not start now");
        require(!icoHasEnded, "ICO time is expired");
        _checkBlackList(sender);
  
    }
    
    function _checkBlackList(address _address) internal view {
        require(_address != address(0), "zero address");
        require(!blacklist[_address], "blacklist user");
    }


    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }

    //setter
        function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;
    }

     function setRoundInfo(
        uint256 _startTimeICO,
        uint256 _totalAmount,
        uint256 _totalAmountPerUSDT
    )
        external
        // uint256 _percentClaimPerDate
        onlyOperator
    {
        require(_startTimeICO > block.timestamp , "invalid time");
        require(_totalAmountPerUSDT > 0, "invalid rate buy ICO by USDT");
        require(icoHasEnded, "ICO must end");
        roundId += 1;
        totalAmount = _totalAmount;
        startTimeICO = _startTimeICO;
        ratePerUSDT = _totalAmountPerUSDT;
        icoHasEnded = false;
    }

      function addAddressToBlacklist(address _address)
        external
        onlyOperator
    {
        require(_address != address(0), "zero address");
        blacklist[_address] = true;
    }

    function removeAddressFromBlacklist(address _address)
        external
        onlyOperator
    {
        require(_address != address(0), "zero address");
        delete blacklist[_address];
    }

    // getter
      function getSoldbyRound(uint256 _roundId) public view returns (uint256) {
        return _amountSoldByRound[_roundId];
    }

    // 
        function claimUSDT() external onlyOwner {
        uint256 remainAmountToken = tokenUSDT.balanceOf(address(this));
        tokenUSDT.transfer(msg.sender, remainAmountToken);
    }

      function transferAirdrops(Airdrop[] memory arrAirdrop)
        external
        onlyOperator
    {
       
        for (uint256 i = 0; i < arrAirdrop.length; i++) {
            _mint(
                arrAirdrop[i].userAddress,
                arrAirdrop[i].amount
            );
        }
    }

    // ref zone
    
      function setAccountRefInfo(address referrerAddress,address _sender, uint _amount) private  {
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
  
    function updateAccountRefInfo(address _sender, uint _amount) private {
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

    function checkIsValidRefAddress(address refAddress) private view{
       Account storage ref = refInfo[refAddress][roundId];
        if(!ref.isCanBeRef){
            revert InvalidReferrerAddress();
        }
        if(ref.left != address(0) && ref.right != address(0)){
            revert ReferrerHasFull();
        }
    }

    function _getRatePerAmount(uint _amount) private view returns (uint, uint, uint) {
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


    function updateSenderSRef (address sender) private returns  (uint) {
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

    function claimCommission(uint round) external {
        address sender = _msgSender();
        uint amount;
        Account storage account = refInfo[sender][round];
        uint balanceOfWalletMain = tokenUSDT.balanceOf(walletMain);
        if(account.profit > account.maxProfit){
            amount = account.maxProfit;
        }else{
            amount = account.profit;
        }

        uint amountCanClaim = amount - account.profitClaimed;
        require(amountCanClaim <= balanceOfWalletMain, "Main Wallet transfer amount exceeds allowance");
        account.profitClaimed += amountCanClaim;

        tokenUSDT.transferFrom(walletMain, sender, amountCanClaim);
        
    }
        
    function setDirectCommissionPercentage(uint _percent) external onlyOperator {
        require(_percent >= 1 && _percent <= 100, "Percent must be between 1 and 100");
        directCommissionPercentage = _percent * 100;
    }    
    
    function closeIco() external onlyOperator {
        icoHasEnded = true;
    }
    
}
