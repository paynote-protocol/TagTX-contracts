// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NetworkSelector} from "../script/NetworkSelector.s.sol";

/// @title NetworkSelector Tests
/// @notice Tests for the NetworkSelector helper contract
contract NetworkSelectorTest is Test, NetworkSelector {
    /*//////////////////////////////////////////////////////////////
                               TEST NETWORK DETECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Test network detection for Sepolia
    function test_getNetworkFromChainId_sepolia() public {
        Network network = getNetworkFromChainId(11155111);
        assertEq(uint256(network), uint256(Network.Sepolia));
        assertEq(getNetworkName(network), "sepolia");
    }

    /// @notice Test network detection for Base Sepolia
    function test_getNetworkFromChainId_baseSepolia() public {
        Network network = getNetworkFromChainId(84532);
        assertEq(uint256(network), uint256(Network.BaseSepolia));
        assertEq(getNetworkName(network), "base-sepolia");
    }

    /// @notice Test network detection for Ethereum Mainnet
    function test_getNetworkFromChainId_ethereum() public {
        Network network = getNetworkFromChainId(1);
        assertEq(uint256(network), uint256(Network.Ethereum));
        assertEq(getNetworkName(network), "ethereum");
    }

    /// @notice Test network detection for unknown chain
    function test_getNetworkFromChainId_unknown() public {
        Network network = getNetworkFromChainId(999999);
        assertEq(uint256(network), uint256(Network.Unknown));
        assertEq(getNetworkName(network), "unknown");
    }

    /// @notice Test isTestnet function
    function test_isTestnet() public {
        // Test with Sepolia chain ID
        vm.chainId(11155111);
        assertTrue(isTestnet());
        assertFalse(isMainnet());

        // Test with Ethereum mainnet chain ID
        vm.chainId(1);
        assertFalse(isTestnet());
        assertTrue(isMainnet());

        // Reset to default
        vm.chainId(31337); // Anvil default
    }

    /// @notice Test getNetworkConfig function
    function test_getNetworkConfig() public {
        // Test with testnet
        vm.chainId(11155111); // Sepolia
        (uint256 fee, bool isTest) = getNetworkConfig();
        assertTrue(isTest);
        assertEq(fee, 0.00001 ether);

        // Test with mainnet
        vm.chainId(1); // Ethereum
        (fee, isTest) = getNetworkConfig();
        assertFalse(isTest);
        assertEq(fee, 0.0001 ether);

        // Reset to default
        vm.chainId(31337);
    }

    /// @notice Test network detection with fork (requires RPC URL)
    /// @dev Run with: forge test --fork-url $SEPOLIA_RPC_URL --match-test test_forkNetworkDetection
    function test_forkNetworkDetection() public {
        // This test demonstrates network detection when running on a fork
        // It will only work when run with --fork-url
        Network currentNetwork = getCurrentNetwork();
        string memory networkName = getCurrentNetworkName();

        console.log("Detected network:", networkName);
        console.log("Chain ID:", block.chainid);

        // When running with --fork-url $SEPOLIA_RPC_URL, this should detect Sepolia
        if (block.chainid == 11155111) {
            assertEq(uint256(currentNetwork), uint256(Network.Sepolia));
            assertEq(networkName, "sepolia");
        } else if (block.chainid == 1) {
            assertEq(uint256(currentNetwork), uint256(Network.Ethereum));
            assertEq(networkName, "ethereum");
        } else if (block.chainid == 84532) {
            assertEq(uint256(currentNetwork), uint256(Network.BaseSepolia));
            assertEq(networkName, "base-sepolia");
        }
        // Add more network checks as needed
    }
}