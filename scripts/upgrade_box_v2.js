const { ethers, upgrades } = require("hardhat");

const PROXY = "0x6e2c852db73D6fCC1CF8fEefDdB05D82f424cA94";

const main = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const BoxV2 = await ethers.getContractFactory("BoxV2");
  const data = await upgrades.upgradeProxy(PROXY, BoxV2);
  console.log(data);
  console.log("Box updated");
};

main();
