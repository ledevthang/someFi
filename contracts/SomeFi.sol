// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SomeFi is ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    //Variables zone
    address public operatorAddress;


    uint private constant oneHundredPercent = 10000;
    uint private directCommissionPercentage = 2500;
    uint public etherValue = 1 ether;
    IERC20 public tokenUSDT;
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
    
    mapping(address => uint256) private _balances; 

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(uint256 => uint256) private _amountSoldByRound;

    mapping(address => mapping(uint256 => UserInfo)) public users;

    mapping(address => mapping(uint256 => Account)) public refInfo;


    mapping(address => bool) public blacklist;



    /// Invalid referrer address
    error InvalidReferrerAddress();
    
    /// Referrer has enough members
    error ReferrerHasFull();

    // ⚪ Events
    event UnlockEvent(
        uint256 unlockAmount,
        uint256 currentTimestamp,
        uint256 lockAmount
    );

    event UpdatedUserLastActiveTime(address user, uint256 timestamp);

    // ⚪ Modifiers
    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "not-operator");
        _;
        
    }

    // ⚪ Functions
    constructor(
        address _usdtContractAddress,
        address _operatorAddress,
        address _walletBackup,
        address _walletMain
    ) ERC20("SomeFi", "SOFI") {
        require(_usdtContractAddress != address(0), "invalid-USDT");
        tokenUSDT = IERC20(_usdtContractAddress);
        operatorAddress = _operatorAddress;
        _decimals = 18;
        uint256 _totalAmount = 10000000 * 10**_decimals;        
        _mint(msg.sender, _totalAmount);
        icoHasEnded = true;
        emit Transfer(address(0), msg.sender, _totalAmount);
        walletBackup = _walletBackup;
        walletMain = _walletMain;
    }

    /**
     * @dev Gets amount sold by round
     */
    function getSoldbyRound(uint256 _roundId) public view returns (uint256) {
        return _amountSoldByRound[_roundId];
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view virtual returns (address) {
        return owner();
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
        // return 1000000 * 10**18;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;
    }

    function burn(uint256 amount) public override {
        _burn(msg.sender, amount);
    }

    function claimUSDT() external onlyOwner {
        uint256 remainAmountToken = tokenUSDT.balanceOf(address(this));
        tokenUSDT.transfer(msg.sender, remainAmountToken);
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


    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - spender cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
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

        tokenUSDT.safeTransferFrom(sender, address(this), amount);
        _buy(sender, buyAmountToken, amount);
    }
      function _buy(
        address sender,
        uint buyAmountToken,
        uint amountUsdt
    ) internal {
        uint half = amountUsdt.div(2);
        users[sender][roundId].amountICO += buyAmountToken;
        // update total sold by round
        _amountSoldByRound[roundId] += buyAmountToken;
        _mint(sender, buyAmountToken);

        tokenUSDT.transfer(walletBackup, half);
        tokenUSDT.transfer(walletMain, half);

    }



    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(_msgSender(), amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

      function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates amount tokens and assigns them to account, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with from set to the zero address.
     *
     * Requirements
     *
     * - to cannot be the zero address.
     */
     
    
    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "BEP20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override {
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(
            amount,
            "BEP20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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

    /**
     * @dev See {BEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20};
     *
     * Requirements:
     * - sender and recipient cannot be the zero address.
     * - sender must have a balance of at least amount.
     * - the caller must have allowance for sender's tokens of at least
     * amount.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "BEP20: transfer amount exceeds allowance"
            )
        );
        return true;
    }




    // Ref function


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

        tokenUSDT.safeTransferFrom(walletMain, sender, amountCanClaim);
        
    }
}

// 1.000.000 - 1000000000000000000000000
// 100 - 100000000000000000000

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4

// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db

//0x0000000000000000000000000000000000000000
