const { expect } = require("chai");
const { ethers } = require("hardhat");
let Box;
let box;

describe("Box", () => {
  beforeEach(async () => {
    Box = await ethers.getContractFactory("Box");
    box = await Box.deploy();
    await box.deployed();
  });

  it("retrieve returns a value previously stored", async () => {
    await box.store(32);

    expect((await box.retrieve()).toString()).to.equal("32");
  });
});
