const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") // 0.25 is premium. It costs 0.25 LINK per request.
const GAS_PRICE_LINK = 1e9 // 1000000000 // link per gas. Calculated value based on the gas price of the chain
// ChainLink Nodes pay the gas fees to give us randomness & do external execution
module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]
    if (developmentChains.includes(network.name)) {
        log("Local network detected! Deploying mocks...")
        // deploy a mock vrfcoordinator...
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks deployed!")
        log("------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
