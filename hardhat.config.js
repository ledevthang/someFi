const { INFURA_API_KEY, ETHERSCAN_API_KEY, PRI_KEY } = require("./secret.json");

require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.10",
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [PRI_KEY],
    },
    bnbTest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [PRI_KEY],
      chainId: 97,
    },
  },
  etherscan: {
    apiKey: "5C5AZ52YM8F29DT7NQX32KM9G4EUYK9V1N",
  },
};
