//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract SomeFi is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable
{
    uint256 private directCommissionPercentage;
    uint256 public etherValue;
    IERC20Upgradeable public tokenUSDT;

    struct Account {
        uint256 profit;
        uint256 maxProfit;
        uint256 profitClaimed;
        uint256 currentPackageSize;
        uint256 totalPackageSize;
        uint256 branchInvestment;
        uint256 commissionPercentage;
        uint256 totalCommissionProfit;
        uint256 directRefProfit;
        bool isCanBeRef;
        address directRef;
        address ref;
        address left;
        address right;
    }

    address backupWallet;
    address mainWallet;

    uint256 public roundId;
    uint256 public startTimeICO;
    uint256 public ratePerUSDT;
    bool public icoHasEnded;

    mapping(address => mapping(uint256 => uint256)) private tokenFromDapp;

    bool public isLockTokenDapp;

    mapping(uint256 => uint256) private _amountSoldByRound;

    mapping(address => mapping(uint256 => Account)) public refInfo;

    mapping(uint256 => address[]) private listBuyers;
    mapping(address => mapping(uint256 => bool)) private isBuyer;

    mapping(address => bool) private operator;

    mapping(address => bool) public blacklist;

    /// Invalid referrer address
    error InvalidReferrerAddress();

    /// Referrer has enough members
    error ReferrerHasFull();

    /// This branch already has enough members
    error ReferrerHasFullThisBranch();

    event buyIco(address buyer, uint256 amount);

    modifier onlyOperator() {
        require(operator[msg.sender], "not-operator");
        _;
    }

    function initialize(
        address _usdtContractAddress,
        address _operatorAddress,
        address _walletBackup,
        address _walletMain
    ) external initializer {
        require(_usdtContractAddress != address(0), "invalid-USDT");
        __ERC20_init("SomeFi", "SOFI");
        __Ownable_init();
        _mint(msg.sender, 10000000000000000000000000);
        tokenUSDT = IERC20Upgradeable(_usdtContractAddress);
        operator[_operatorAddress] = true;
        icoHasEnded = true;
        backupWallet = _walletBackup;
        mainWallet = _walletMain;
        directCommissionPercentage = 5000;
        etherValue = 1 ether;
    }

    function buyICOByUSDT(
        address ref,
        address directRef,
        bool isLeft,
        uint256 amount
    ) external {
        address sender = _msgSender();
        _precheckBuy(sender);
        _addUserToList();
        if (!refInfo[sender][roundId].isCanBeRef) {
            setAccountRefInfo(sender, ref, directRef, isLeft, amount);
        } else {
            updateAccountRefInfo(sender, amount);
        }

        uint256 buyAmountToken = amount * ratePerUSDT;

        tokenUSDT.transferFrom(sender, address(this), amount);
        _buy(sender, buyAmountToken, amount);
        emit buyIco(sender, amount);
    }

    function updateDirectProfit(Account memory _sender, uint256 _amount)
        private
    {
        Account storage directRef = refInfo[_sender.directRef][roundId];
        directRef.directRefProfit += ((_amount * directCommissionPercentage) /
            10000);
        if (directRef.left != address(0) && directRef.right != address(0)) {
            directRef.profit += ((_amount * directCommissionPercentage) /
                10000);
        }
    }

    //get list users by roundId
    function getListUserByRoundId(uint256 _roundId)
        external
        view
        returns (address[] memory)
    {
        return listBuyers[_roundId];
    }

    function _addUserToList() private {
        if (!isBuyer[msg.sender][roundId]) {
            isBuyer[msg.sender][roundId] = true;
            listBuyers[roundId].push(msg.sender);
        }
    }

    function _buy(
        address sender,
        uint256 buyAmountToken,
        uint256 amountUsdt
    ) internal {
        uint256 half = amountUsdt / 2;
        _amountSoldByRound[roundId] += buyAmountToken;
        _mint(sender, buyAmountToken);

        tokenUSDT.transfer(backupWallet, half);
        tokenUSDT.transfer(mainWallet, half);
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

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operator[_operatorAddress] = true;
    }

    function setRoundInfo(uint256 _startTimeICO, uint256 _totalAmountPerUSDT)
        external
        // uint256 _percentClaimPerDate
        onlyOperator
    {
        require(_startTimeICO > block.timestamp, "invalid time");
        require(_totalAmountPerUSDT > 0, "invalid rate buy ICO by USDT");
        require(icoHasEnded, "ICO must end");
        roundId += 1;
        startTimeICO = _startTimeICO;
        ratePerUSDT = _totalAmountPerUSDT;
        icoHasEnded = false;
    }

    function addAddressToBlacklist(address _address) external onlyOperator {
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

    function getSoldbyRound(uint256 _roundId) public view returns (uint256) {
        return _amountSoldByRound[_roundId];
    }

    function claimUSDT() external onlyOwner {
        uint256 remainAmountToken = tokenUSDT.balanceOf(address(this));
        tokenUSDT.transfer(msg.sender, remainAmountToken);
    }

    function setAccountRefInfo(
        address _sender,
        address referrerAddress,
        address directRef,
        bool isLeft,
        uint256 _amount
    ) private {
        (
            uint256 maxProfit,
            uint256 commissionPercentage,
            uint256 currentPackageSize
        ) = _getPkgRatePerAmount(_amount);
        Account storage account = refInfo[_sender][roundId];
        account.maxProfit = maxProfit;
        account.isCanBeRef = true;
        account.currentPackageSize = currentPackageSize;
        account.totalPackageSize = currentPackageSize;
        account.commissionPercentage = commissionPercentage;
        account.branchInvestment += currentPackageSize;
        if (referrerAddress != address(0) && referrerAddress != _sender) {
            checkIsValidRefAddress(referrerAddress);
            checkLeftRightAvailable(referrerAddress, isLeft);
            account.ref = referrerAddress;
            account.directRef = directRef;
            Account storage referrer = refInfo[referrerAddress][roundId];
            referrer.branchInvestment += currentPackageSize;

            if (isLeft) {
                referrer.left = _sender;
            } else {
                referrer.right = _sender;
            }
            updateDirectProfit(account, _amount);
            updateSenderSRef(_sender);
        }
    }

    function updateAccountRefInfo(address _sender, uint256 _amount) private {
        (
            uint256 maxProfit,
            uint256 commissionPercentage,
            uint256 currentPackageSize
        ) = _getPkgRatePerAmount(_amount);
        Account storage account = refInfo[_sender][roundId];
        Account storage referrer = refInfo[account.ref][roundId];
        account.maxProfit += maxProfit;
        account.branchInvestment += currentPackageSize;
        account.totalPackageSize += currentPackageSize;
        referrer.branchInvestment += currentPackageSize;
        if (commissionPercentage > account.commissionPercentage) {
            account.commissionPercentage = commissionPercentage;
            account.currentPackageSize = currentPackageSize;
        }
        if (account.ref != address(0)) {
            updateDirectProfit(account, _amount);
            updateSenderSRef(_sender);
        }
    }

    function checkIsValidRefAddress(address refAddress) private view {
        Account storage ref = refInfo[refAddress][roundId];
        if (!ref.isCanBeRef) {
            revert InvalidReferrerAddress();
        }
        if (ref.left != address(0) && ref.right != address(0)) {
            revert ReferrerHasFull();
        }
    }

    function checkLeftRightAvailable(address refAddress, bool isLeft)
        private
        view
    {
        Account storage ref = refInfo[refAddress][roundId];
        if (isLeft) {
            if (ref.left != address(0)) {
                revert ReferrerHasFullThisBranch();
            }
        } else {
            if (ref.right != address(0)) {
                revert ReferrerHasFullThisBranch();
            }
        }
    }

    function _getPkgRatePerAmount(uint256 _amount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 maxProfit = 0;
        uint256 commissionPercentage = 0;
        uint256 currentPackageSize = 0;
        if (_amount >= 5000 * etherValue) {
            maxProfit = 5000 * 3 * etherValue;
            commissionPercentage = 1000;
            currentPackageSize = 5000 * etherValue;
        } else if (_amount >= 3000 * etherValue) {
            maxProfit = 3000 * 3 * etherValue;
            commissionPercentage = 900;
            currentPackageSize = 3000 * etherValue;
        } else if (_amount >= 1000 * etherValue) {
            maxProfit = 1000 * 3 * etherValue;
            commissionPercentage = 800;
            currentPackageSize = 1000 * etherValue;
        } else if (_amount >= 500 * etherValue) {
            maxProfit = 500 * 3 * etherValue;
            commissionPercentage = 700;
            currentPackageSize = 500 * etherValue;
        } else if (_amount >= 100 * etherValue) {
            maxProfit = 100 * 3 * etherValue;
            commissionPercentage = 500;
            currentPackageSize = 100 * etherValue;
        }

        return (maxProfit, commissionPercentage, currentPackageSize);
    }

    function updateTotalCommissionProfit(
        address _refAddress,
        address _weakBranchAddress
    ) private {
        Account storage ref = refInfo[_refAddress][roundId];
        Account storage weakBranch = refInfo[_weakBranchAddress][roundId];
        ref.totalCommissionProfit =
            ((weakBranch.branchInvestment * ref.commissionPercentage) / 10000) +
            weakBranch.totalCommissionProfit;
    }

    function updateRefProfit(address _refAddress, address _weakBranchAddress)
        private
    {
        Account storage ref = refInfo[_refAddress][roundId];
        Account storage weakBranch = refInfo[_weakBranchAddress][roundId];

        ref.profit =
            ((weakBranch.currentPackageSize * directCommissionPercentage) /
                10000) +
            ref.totalCommissionProfit +
            ref.directRefProfit;
    }

    function updateSenderSRef(address sender) private returns (uint256) {
        Account storage currentAddress = refInfo[sender][roundId];
        address _address = sender;
        uint256 countRefLevel = 0;
        while (currentAddress.ref != address(0) && countRefLevel < 10) {
            Account storage referrer = refInfo[currentAddress.ref][roundId];
            uint256 leftBranchInvestment = (
                referrer.left == address(0)
                    ? 0
                    : refInfo[referrer.left][roundId].branchInvestment
            );
            uint256 rightBranchInvestment = (
                referrer.right == address(0)
                    ? 0
                    : refInfo[referrer.right][roundId].branchInvestment
            );
            referrer.branchInvestment =
                referrer.totalPackageSize +
                leftBranchInvestment +
                rightBranchInvestment;
            if (_address == referrer.left) {
                if (referrer.right != address(0)) {
                    Account storage right = refInfo[referrer.right][roundId];
                    if (
                        currentAddress.branchInvestment > right.branchInvestment
                    ) {
                        updateTotalCommissionProfit(
                            currentAddress.ref,
                            referrer.right
                        );
                        updateRefProfit(currentAddress.ref, referrer.right);
                    } else {
                        updateTotalCommissionProfit(
                            currentAddress.ref,
                            _address
                        );
                        updateRefProfit(currentAddress.ref, _address);
                    }
                }
            } else {
                if (referrer.left != address(0)) {
                    Account storage left = refInfo[referrer.left][roundId];
                    if (
                        currentAddress.branchInvestment > left.branchInvestment
                    ) {
                        updateTotalCommissionProfit(
                            currentAddress.ref,
                            referrer.left
                        );
                        updateRefProfit(currentAddress.ref, referrer.left);
                    } else {
                        updateTotalCommissionProfit(
                            currentAddress.ref,
                            _address
                        );
                        updateRefProfit(currentAddress.ref, _address);
                    }
                }
            }
            _address = currentAddress.ref; // 0x83B5064fcAB70a342d72b7a1DF3B091D2AB12693
            currentAddress = refInfo[currentAddress.ref][roundId]; // info of 0x83B5064fcAB70a342d72b7a1DF3B091D2AB12693
            countRefLevel++;
        }
        return countRefLevel;
    }

    function claimCommission(uint256 round) external {
        address sender = _msgSender();
        uint256 amount;
        Account storage account = refInfo[sender][round];
        uint256 balanceOfMainWallet = tokenUSDT.balanceOf(mainWallet);
        _checkBlackList(sender);
        if (account.profit > account.maxProfit) {
            amount = account.maxProfit;
        } else {
            amount = account.profit;
        }

        uint256 amountCanClaim = amount - account.profitClaimed;
        require(
            amountCanClaim <= balanceOfMainWallet,
            "Main Wallet transfer amount exceeds allowance"
        );

        tokenUSDT.transferFrom(mainWallet, sender, amountCanClaim);
        account.profitClaimed += amountCanClaim;
    }

    function setDirectCommissionPercentage(uint256 _percent)
        external
        onlyOperator
    {
        require(
            _percent >= 1 && _percent <= 100,
            "Percent must be between 1 and 100"
        );
        directCommissionPercentage = _percent * 100;
    }

    function closeIco() external onlyOperator {
        icoHasEnded = true;
    }

    // lock transfer token from Dapp
    function setIsLockTokenDapp(bool _isLock) external onlyOwner {
        isLockTokenDapp = _isLock;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        if (isLockTokenDapp) {
            uint256 amountToken = balanceOf(owner);
            uint256 availableToken = amountToken -
                tokenFromDapp[owner][roundId];
            require(
                availableToken >= amount,
                "ERC20: transfer amount exceeds balance"
            );
            _transfer(owner, to, amount);
            return true;
        } else {
            return super.transfer(to, amount);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0) && isLockTokenDapp) {
            tokenFromDapp[to][roundId] += amount;
        } else {
            super._beforeTokenTransfer(from, to, amount);
        }
    }
}
