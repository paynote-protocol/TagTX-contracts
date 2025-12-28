// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PaynoteRegistry} from "../src/PaynoteRegistry.sol";

/// @title DeployPaynoteRegistry
/// @notice Deployment script for PaynoteRegistry to Base mainnet and testnet
/// @dev Usage:
///   forge script script/DeployPaynoteRegistry.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract DeployPaynoteRegistry is Script {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default fee: 0.0001 ETH (~$0.35 at current prices)
    uint256 public constant DEFAULT_FEE = 0.0001 ether;

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Get deployment configuration from environment variables
    /// @return fee The initial fee for attaching notes
    /// @return ownerAddress The initial owner of the registry
    function getConfig()
        internal
        view
        returns (uint256 fee, address ownerAddress)
    {
        // Fee can be overridden via environment variable (in wei)
        fee = vm.envOr("INITIAL_FEE", DEFAULT_FEE);

        // Owner address is required
        ownerAddress = vm.envAddress("OWNER_ADDRESS");

        // Validate owner is not zero address
        require(ownerAddress != address(0), "OWNER_ADDRESS cannot be zero");
    }

    /*//////////////////////////////////////////////////////////////
                               DEPLOY
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy the PaynoteRegistry contract
    /// @return registry The deployed PaynoteRegistry contract
    function run() external returns (PaynoteRegistry registry) {
        // Get configuration
        (uint256 fee, address ownerAddress) = getConfig();

        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== PaynoteRegistry Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Owner:", ownerAddress);
        console.log("Initial fee:", fee, "wei");
        console.log("Initial fee:", fee / 1e14, "* 0.0001 ETH");

        vm.startBroadcast(deployerPrivateKey);

        registry = new PaynoteRegistry(fee, ownerAddress);

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("PaynoteRegistry deployed to:", address(registry));
        console.log("Version:", registry.VERSION());

        // Verify deployment
        require(registry.fee() == fee, "Fee mismatch");
        require(registry.owner() == ownerAddress, "Owner mismatch");

        return registry;
    }
}
