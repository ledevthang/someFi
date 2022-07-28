// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Wallet is Ownable {
    IERC20 token;

    mapping(address => bool) isSupportToken;
    address[] listToken;

    constructor(address[] memory _addressTokens){
        require(_addressTokens.length > 0, "Invalid lenght");
        for(uint i = 0; i < _addressTokens.length; i++){
            address addressToken = _addressTokens[i];
            require(addressToken != address(0), "Invalid address");
            isSupportToken[addressToken] = true;
            listToken.push(addressToken);
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function transferErcToken(address _tokenAddress, address _recipient, uint _amount) external onlyOwner {
        require(isSupportToken[_tokenAddress], "Invalid address token");
        require(_recipient != address(0), "Invalid address recipient");
        token = IERC20(_tokenAddress);
        require(_amount <= token.balanceOf(address(this)), "Invalid amount");
        token.transfer(_recipient, _amount);
    }

    function transferNativeToken(address _recipient, uint _amount) external onlyOwner {
        require(_recipient != address(0), "Invalid address recipient");
        require(_amount <= address(this).balance, "Invalid amount");
        (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    function withDrawAllToken() external onlyOwner {
        for(uint i = 0; i < listToken.length; i++){
            token = IERC20(listToken[i]);
            uint balanceAcc = token.balanceOf(address(this));
            if(balanceAcc > 0){
               token.transfer(owner(), balanceAcc);
            }
        }
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Faild to withdraw token");

    }
    
    
    function approveUSDT(address _recipient,uint amount) external onlyOwner {
        token = IERC20(usdtAddress);
        token.approve(_recipient, amount);
    }


    function addManyTokenSupport(address[] memory _addressTokens) external onlyOwner {
         require(_addressTokens.length > 0, "Invalid lenght");
        for(uint i = 0; i < _addressTokens.length; i++){
            address addressToken = _addressTokens[i];
            require(addressToken != address(0), "Invalid address");
            isSupportToken[addressToken] = true;
            listToken.push(addressToken);
        }        
    }

}
