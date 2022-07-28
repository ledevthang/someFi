// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;


interface ITransferLockToken {
    function transferLockToken(address recipient, uint256 amount)
        external
        returns (bool);
}


// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SomeFi is ERC20Burnable, Ownable, ITransferLockToken {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // ⚪ Variables zone
    IERC20 public tokenUSDT;
    uint256 private _totalSupply;
    uint8 private _decimals;
    struct UserInfo {
        uint256 amountICO; 
        uint256 amountClaimPerSec;
        uint256 claimAt;
        bool isSetup;

        uint profit; // current profit
        uint maxProfit; // maximun profit that can be earned
        uint packageSize; // package size user invest in
        uint commissionPercentage; // commission percenatage can earned by packageSize
        address ref; // address of referral
        address left; // address of child left
        address right; // address of child right
    }
    struct Airdrop {
        address userAddress;
        uint256 amount;
    }
    // Information of Round
    uint256 public roundId;
    uint256 public totalAmount;
    uint256 public startTimeICO;
    uint256 public endTimeICO;
    uint256 public ratePerUSDT;
    
    mapping(address => uint256) private _balances; 

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(uint256 => uint256) private _amountSoldByRound;

    mapping(address => UserInfo) public users;

    mapping(address => bool) public blacklist;

    mapping(address => bool) public unlockList;

    address public operatorAddress;

    uint256 public unlockTime;
    

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
        address _operatorAddress
    ) ERC20("SomeFi", "SOFI") {
        require(_usdtContractAddress != address(0), "invalid-USDT");

        tokenUSDT = IERC20(_usdtContractAddress);
        operatorAddress = _operatorAddress;
        _decimals = 18;

        uint256 _totalAmount = 10000000 * 10**_decimals;
        
        _mint(msg.sender, _totalAmount);
        
        emit Transfer(address(0), msg.sender, _totalAmount);
    
    }


    function whitelistUnlock(
        address[] calldata _unlockAddresses,
        bool[] calldata _isUnlockAddress
    ) external onlyOperator returns (bool) {
        uint256 count = _unlockAddresses.length;
        require(count < 201, "Array Overflow");
        for (uint256 i = 0; i < count; i++) {
            require(_unlockAddresses[i] != address(0), "zero-address");
            unlockList[_unlockAddresses[i]] = _isUnlockAddress[i];
        }
        return true;
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

    function unlockToken() external {
        require(unlockTime != 0 && unlockTime < block.timestamp, "locked");

        address sender = _msgSender();
        if (users[sender].claimAt < unlockTime)
            users[sender].claimAt = unlockTime;
        require(users[sender].amountICO > 0, "no locked token to be unlocked");

        uint256 currentTimestamp = block.timestamp;
        uint256 unlockAmount = _getUnlockAmount(sender);
        if (unlockAmount > 0) {
            users[sender].amountICO = users[sender].amountICO.sub(unlockAmount);
            users[sender].claimAt = currentTimestamp;
        }

        emit UnlockEvent(
            unlockAmount,
            currentTimestamp,
            users[sender].amountICO
        );
    }

    function setOperator(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;
    }

    function burn(uint256 amount) public override {
        _burn(msg.sender, amount);
    }

    function getAvailableBalance(address account)
        external
        view
        returns (uint256)
    {
        uint256 availableAmount = _balances[account] - users[account].amountICO;
        if (users[account].amountICO > 0) {
            uint256 unlockAmount = _getUnlockAmount(account);
            availableAmount = availableAmount.add(unlockAmount);
        }

        return availableAmount;
    }

    function getUnlockAmount(address account)
        external
        view
        returns (uint256)
    {
        return _getUnlockAmount(account);
    }

    // function claimBNB() external onlyOwner {
    //     payable(msg.sender).transfer(address(this).balance);
    // }

    function claimUSDT() external onlyOwner {
        uint256 remainAmountToken = tokenUSDT.balanceOf(address(this));
        tokenUSDT.transfer(msg.sender, remainAmountToken);
    }

    function claimToken() external onlyOwner {
        address sender = _msgSender();
        uint256 remainAmountToken = this.balanceOf(address(this));
        this.transfer(sender, remainAmountToken);
    }

    function setRoundInfo(
        uint256 _startTimeICO,
        uint256 _endTimeICO,
        uint256 _roundId,
        uint256 _totalAmount,
        uint256 _totalAmountPerUSDT
    )
        external
        // uint256 _percentClaimPerDate
        onlyOperator
    {
        require(_startTimeICO < _endTimeICO, "invalid time");
        require(_totalAmountPerUSDT > 0, "invalid rate buy ICO by USDT");
        // require(_percentClaimPerDate > 0, "invalid unlock percent per day");

        roundId = _roundId;
        totalAmount = _totalAmount;
        startTimeICO = _startTimeICO;
        endTimeICO = _endTimeICO;
        ratePerUSDT = _totalAmountPerUSDT;
    }



    function setUnlockTime(uint256 _unlockTime) external onlyOperator {
        unlockTime = _unlockTime;
    }

   

    function addAddressToBlacklist(address _address, bool _isBlackAddress)
        external
        onlyOperator
    {
        require(_address != address(0), "zero address");
        blacklist[_address] = _isBlackAddress;
    }

    function transferAirdrops(Airdrop[] memory arrAirdrop, uint256 _totalAmount)
        external
        onlyOperator
    {
        _precheckContractAmount(_totalAmount);
        for (uint256 i = 0; i < arrAirdrop.length; i++) {
            this.transferLockToken(
                arrAirdrop[i].userAddress,
                arrAirdrop[i].amount
            );
        }
    }

    function transferLockToken(address recipient, uint256 amount)
        external
        virtual
        override
        returns (bool)
    {
        users[recipient].amountICO += amount;
        users[msg.sender].amountICO -= amount;
        _transfer(_msgSender(), recipient, amount);
        return true;
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

    /**
     * Returns the latest price
     */
    // function getLatestPrice() public view returns (int256) {
    //     (, int256 price, , , ) = priceFeed.latestRoundData();
    //     return price;
    // }

    // function getPriceFeedDecimals() internal view returns(uint){
    //     uint decimal = priceFeed.decimals();
    //     return decimal;
    // }

    function buyICOByUSDT( uint256 amount)
        external
        payable
    {
        _checkBlackList(msg.sender);

        uint256 buyAmountToken = amount * ratePerUSDT;

        address sender = _msgSender();
        tokenUSDT.safeTransferFrom(sender, address(this), amount);
        _buy(sender, buyAmountToken);
    }

    // function buyICObyBNB() external payable {
    //     _checkBlackList(msg.sender);

    //     int256 bnbUSDPrice = this.getLatestPrice();

    //     uint priceDecimal = getPriceFeedDecimals();

    //     uint256 amount = msg.value;

    //     uint256 totalUSDConverted = amount * uint(bnbUSDPrice) / priceDecimal;
    //     uint256 buyAmountToken = totalUSDConverted.mul(ratePerBUSD);

    //     address sender = _msgSender();
    //     _buy(sender, buyAmountToken);
    // }

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
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        // whitelist
        if (!unlockList[sender] && (sender != address(this))) {
            uint256 availableAmount = _balances[sender].sub(
                users[sender].amountICO
            );
            require(
                availableAmount >= amount,
                "some available balance has been locked"
            );
        }

        _balances[sender] = _balances[sender].sub(
            amount,  
            "BEP20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
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

    function _getUnlockAmount(address account)
        internal
        view
        returns (uint256)
    {
        if (unlockTime == 0 || unlockTime > block.timestamp) return 0;
        if (users[account].amountICO == 0) return 0;
        uint256 claimAt = users[account].claimAt;
        if (claimAt < unlockTime) claimAt = unlockTime;

        return users[account].amountICO;
    }

    function _precheckContractAmount(uint256 transferAmount) internal view {
        uint256 remainAmountToken = this.balanceOf(address(this));
        require(transferAmount <= remainAmountToken, "not enough amount");
    }

    function _precheckBuy(uint256 buyAmountToken) internal view {
        require(block.timestamp >= startTimeICO, "ICO time dose not start now");
        require(block.timestamp <= endTimeICO, "ICO time is expired");
        require(unlockTime != 0, "unlockTime must be != 0");

        uint256 remainAmountToken = this.balanceOf(address(this));
        require(buyAmountToken <= remainAmountToken, "not enough amount");
    }

   

    function _buy(
        address sender,
        uint256 buyAmountToken
    ) internal {
        _precheckBuy(buyAmountToken);

        users[sender].amountICO += buyAmountToken;

        // update total sold by round
        _amountSoldByRound[roundId] += buyAmountToken;

        _mint(sender, buyAmountToken);
    }

    
    function _checkBlackList(address _address) internal view {
        require(_address != address(0), "zero address");
        require(!blacklist[_address], "blacklist");
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
}