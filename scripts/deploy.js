// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

//traderjoe testnet contract: 0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const CoqDoqs = await hre.ethers.getContractFactory("CoqDoqs");
  // Replace 'routerAddress' and 'stakingContractAddress' with actual contract addresses
  const coqDoqs = await CoqDoqs.deploy("routerAddress", "stakingContractAddress");

  await coqDoqs.deployed();

  console.log("CoqDoqs deployed to:", coqDoqs.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });