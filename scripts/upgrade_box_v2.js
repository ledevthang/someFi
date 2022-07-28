const { ethers, upgrades } = require("hardhat");

const PROXY = "0x0B0C16fAb9E743738eCf20095020684358a121E6";

const main = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const BoxV2 = await ethers.getContractFactory("BoxV2");
  const data = await upgrades.upgradeProxy(PROXY, BoxV2);
  console.log(data);
  console.log("Box updated");
};

main();
