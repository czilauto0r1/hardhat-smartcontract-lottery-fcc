const { run } = require("hardhat")

async function verify(contractAddress, args) {
    console.log("Verifying contract...")
    try {
        // if contract is verified already then should show us that info
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e) {
        // showing error
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already verified")
        } else {
            console.log(e)
        }
    }
}

module.exports = { verify }
