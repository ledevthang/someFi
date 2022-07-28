const { ethers, upgrades } = require("hardhat");

const main = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Box = await ethers.getContractFactory("Box");
  console.log("Deploying Box...");

  const box = await upgrades.deployProxy(Box, [42], {
    initializer: "initialize",
  });

  console.log("Box deployed to:" + box.address);
};

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });
