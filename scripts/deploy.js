const { ethers, upgrades } = require("hardhat");

const main = async () => {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const SomeFi = await ethers.getContractFactory("SomeFi");
  console.log("Deploying SomeFi...");

  const somefi = await upgrades.deployProxy(
    SomeFi,
    [
      "0x4F5A330b999F150072943497EA17f5A9d2Cd2DA0",
      "0xb791517E95fe28d0FedE8F07C337baE0394ac9dA",
      "0x3B31D47582E8FEC545F47450c579c70314be2Cd2",
      "0x55A5AA002f9616BC5928f70Dc5f657B9A8777Ea9",
    ],
    {
      initializer: "initialize",
    }
  );

  console.log("SomeFi deployed to: " + somefi.address);
};

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.log(e);
    process.exit(1);
  });

// token 0x4F5A330b999F150072943497EA17f5A9d2Cd2DA0;
// wallet1 0x3B31D47582E8FEC545F47450c579c70314be2Cd2
// wallet2 0x55A5AA002f9616BC5928f70Dc5f657B9A8777Ea9
// somefi 0xd2768da992D60a88aD72ac08B153bB39FbDEb463
