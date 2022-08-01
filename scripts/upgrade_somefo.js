const { ethers, upgrades } = require("hardhat");

const PROXY = "0xd2768da992D60a88aD72ac08B153bB39FbDEb463";

const main = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const SomeFiV2 = await ethers.getContractFactory("SomeFiV2");
  const data = await upgrades.upgradeProxy(PROXY, SomeFiV2);
  console.log(data);
  console.log("update");
};

main();
