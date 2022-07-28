const { expect } = require("chai");

const { ethers, upgrades } = require("hardhat");

let Box;
let box;

describe("Box (proxy)", () => {
  beforeEach(async () => {
    Box = await ethers.getContractFactory("Box");
    box = await upgrades.deployProxy(Box, [42], { initializer: "store" });
  });

  it("retrieve returns a  value previously initialized", async () => {
    expect((await box.retrieve()).toString()).to.equal("42");
  });
});
