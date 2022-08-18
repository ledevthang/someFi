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
    uint256 private oneHundredPercent;
    uint256 private directCommissionPercentage;
    uint256 public etherValue;
    IERC20Upgradeable public tokenUSDT;
    uint256 private _totalSupply;
    uint8 private _decimals;

    struct Account {
        uint256 profit;
        uint256 maxProfit;
        uint256 profitClaimed;
        uint256 currentPackageSize;
        uint256 totalPackageSize;
        uint256 branchInvestment;
        uint256 commissionPercentage;
        uint256 totalCommissionProfit;
        bool isCanBeRef;
        address ref;
        address left;
        address right;
    }

    address backupWallet;
    address mainWallet;

    // Information of Round
    uint256 public roundId;
    uint256 public totalAmount;
    uint256 public startTimeICO;
    uint256 public ratePerUSDT;
    uint256[5] public pkgAmount;
    bool public icoHasEnded;

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

    // ⚪ Modifiers
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
        oneHundredPercent = 10000;
        directCommissionPercentage = 5000;
        etherValue = 1 ether;
    }

    function buyICOByUSDT(
        address ref,
        bool isLeft,
        uint256 amount
    ) external {
        address sender = _msgSender();
        _precheckBuy(sender);
        _addUserToList();
        if (!refInfo[sender][roundId].isCanBeRef) {
            setAccountRefInfo(sender, ref, isLeft, amount);
        } else {
            updateAccountRefInfo(sender, amount);
        }

        uint256 buyAmountToken = amount * ratePerUSDT;

        tokenUSDT.transferFrom(sender, address(this), amount);
        _buy(sender, buyAmountToken, amount);
        emit buyIco(sender, amount);
    }

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

        // update total sold by round
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

    //setter
    function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operator[_operatorAddress] = true;
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
        require(_startTimeICO > block.timestamp, "invalid time");
        require(_totalAmountPerUSDT > 0, "invalid rate buy ICO by USDT");
        require(icoHasEnded, "ICO must end");
        roundId += 1;
        totalAmount = _totalAmount;
        startTimeICO = _startTimeICO;
        ratePerUSDT = _totalAmountPerUSDT;
        icoHasEnded = false;
    }

    function setPkgRate(uint256[] memory _pkgAmount) external {
        pkgAmount[0] = _pkgAmount[0];
        pkgAmount[1] = _pkgAmount[1];
        pkgAmount[2] = _pkgAmount[2];
        pkgAmount[3] = _pkgAmount[3];
        pkgAmount[4] = _pkgAmount[4];
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

    // getter
    function getSoldbyRound(uint256 _roundId) public view returns (uint256) {
        return _amountSoldByRound[_roundId];
    }

    //
    function claimUSDT() external onlyOwner {
        uint256 remainAmountToken = tokenUSDT.balanceOf(address(this));
        tokenUSDT.transfer(msg.sender, remainAmountToken);
    }

    // ref zone

    function setAccountRefInfo(
        address _sender,
        address referrerAddress,
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
        if (referrerAddress != address(0)) {
            checkIsValidRefAddress(referrerAddress);
            checkLeftRightAvailable(referrerAddress, isLeft);
            account.ref = referrerAddress;
            Account storage referrer = refInfo[referrerAddress][roundId];
            referrer.branchInvestment += currentPackageSize;

            if (isLeft) {
                referrer.left = _sender;
            } else {
                referrer.right = _sender;
            }
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
        if (_amount >= pkgAmount[4] * etherValue) {
            maxProfit = pkgAmount[4] * 3 * etherValue;
            commissionPercentage = 1000;
            currentPackageSize = pkgAmount[4] * etherValue;
        } else if (_amount >= pkgAmount[3] * etherValue) {
            maxProfit = pkgAmount[3] * 3 * etherValue;
            commissionPercentage = 900;
            currentPackageSize = pkgAmount[3] * etherValue;
        } else if (_amount >= pkgAmount[2] * etherValue) {
            maxProfit = pkgAmount[2] * 3 * etherValue;
            commissionPercentage = 800;
            currentPackageSize = pkgAmount[2] * etherValue;
        } else if (_amount >= pkgAmount[1] * etherValue) {
            maxProfit = pkgAmount[1] * 3 * etherValue;
            commissionPercentage = 700;
            currentPackageSize = pkgAmount[1] * etherValue;
        } else if (_amount >= pkgAmount[0] * etherValue) {
            maxProfit = pkgAmount[0] * 3 * etherValue;
            commissionPercentage = 500;
            currentPackageSize = pkgAmount[0] * etherValue;
        }

        return (maxProfit, commissionPercentage, currentPackageSize);
    }

    function updateSenderSRef(address sender) private returns (uint256) {
        Account storage currentAddress = refInfo[sender][roundId];
        address _address = sender;
        uint256 countRefLevel = 0;
        while (currentAddress.ref != address(0) && countRefLevel < 15) {
            Account storage referrer = refInfo[currentAddress.ref][roundId];

            referrer.branchInvestment =
                referrer.totalPackageSize +
                refInfo[referrer.left][roundId].branchInvestment +
                refInfo[referrer.right][roundId].branchInvestment;
            if (_address == referrer.left) {
                if (referrer.right != address(0)) {
                    Account storage right = refInfo[referrer.right][roundId];
                    if (
                        currentAddress.branchInvestment > right.branchInvestment
                    ) {
                        referrer.totalCommissionProfit =
                            ((right.branchInvestment *
                                referrer.commissionPercentage) /
                                oneHundredPercent) +
                            refInfo[referrer.right][roundId]
                                .totalCommissionProfit +
                            currentAddress.totalCommissionProfit;

                        referrer.profit =
                            ((right.currentPackageSize *
                                directCommissionPercentage) /
                                oneHundredPercent) +
                            referrer.totalCommissionProfit;
                    } else {
                        referrer.totalCommissionProfit =
                            ((currentAddress.branchInvestment *
                                referrer.commissionPercentage) /
                                oneHundredPercent) +
                            currentAddress.totalCommissionProfit +
                            refInfo[referrer.right][roundId]
                                .totalCommissionProfit;

                        referrer.profit =
                            ((currentAddress.currentPackageSize *
                                directCommissionPercentage) /
                                oneHundredPercent) +
                            referrer.totalCommissionProfit;
                    }
                }
            } else {
                Account storage left = refInfo[referrer.left][roundId];
                if (currentAddress.branchInvestment > left.branchInvestment) {
                    referrer.totalCommissionProfit =
                        ((left.branchInvestment *
                            referrer.commissionPercentage) /
                            oneHundredPercent) +
                        refInfo[referrer.left][roundId].totalCommissionProfit +
                        currentAddress.totalCommissionProfit;

                    referrer.profit =
                        ((left.currentPackageSize *
                            directCommissionPercentage) / oneHundredPercent) +
                        referrer.totalCommissionProfit;
                } else {
                    referrer.totalCommissionProfit =
                        ((currentAddress.branchInvestment *
                            referrer.commissionPercentage) /
                            oneHundredPercent) +
                        currentAddress.totalCommissionProfit +
                        refInfo[referrer.left][roundId].totalCommissionProfit;

                    referrer.profit =
                        ((currentAddress.currentPackageSize *
                            directCommissionPercentage) / oneHundredPercent) +
                        referrer.totalCommissionProfit;
                }
            }
            _address = currentAddress.ref;
            currentAddress = refInfo[currentAddress.ref][roundId];
            countRefLevel++;
        }
        return countRefLevel;
    }

    function claimCommission(uint256 round) external {
        address sender = _msgSender();
        uint256 amount;
        Account storage account = refInfo[sender][round];
        uint256 balanceOfMainWallet = tokenUSDT.balanceOf(mainWallet);
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
        account.profitClaimed += amountCanClaim;

        tokenUSDT.transferFrom(mainWallet, sender, amountCanClaim);
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
}

