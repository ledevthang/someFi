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
