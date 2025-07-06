const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment to Core Blockchain...");
  
  // Get the contract factory
  const ProcrastinationMiningProtocol = await ethers.getContractFactory("ProcrastinationMiningProtocol");
  
  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  // Check deployer balance
  const balance = await deployer.getBalance();
  console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");
  
  // Deploy the contract
  console.log("Deploying ProcrastinationMiningProtocol...");
  const procrastinationContract = await ProcrastinationMiningProtocol.deploy();
  
  // Wait for deployment to complete
  await procrastinationContract.deployed();
  
  console.log("✅ ProcrastinationMiningProtocol deployed successfully!");
  console.log("📋 Contract Address:", procrastinationContract.address);
  console.log("🔗 Network: Core Testnet");
  console.log("⛽ Gas Price:", await ethers.provider.getGasPrice());
  
  // Verify deployment by checking some basic contract state
  const nextTaskId = await procrastinationContract.nextTaskId();
  const minStake = await procrastinationContract.MIN_STAKE();
  
  console.log("\n📊 Contract Verification:");
  console.log("Next Task ID:", nextTaskId.toString());
  console.log("Minimum Stake:", ethers.utils.formatEther(minStake), "ETH");
  
  // Save deployment info
  const deploymentInfo = {
    contractName: "ProcrastinationMiningProtocol",
    contractAddress: procrastinationContract.address,
    deployer: deployer.address,
    network: "Core Testnet",
    deploymentTime: new Date().toISOString(),
    transactionHash: procrastinationContract.deployTransaction.hash
  };
  
  console.log("\n📝 Deployment Summary:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  
  console.log("\n🎉 Deployment completed successfully!");
  console.log("You can now interact with your contract at:", procrastinationContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
