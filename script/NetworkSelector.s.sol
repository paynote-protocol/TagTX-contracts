// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

/// @title NetworkSelector
/// @notice Helper contract for selecting network configuration based on chain ID
/// @dev Used in deployment and testing scripts to automatically detect the network
contract NetworkSelector is Script {
    /*//////////////////////////////////////////////////////////////
                              NETWORK ENUM
    //////////////////////////////////////////////////////////////*/

    enum Network {
        Ethereum,
        Sepolia,
        Base,
        BaseSepolia,
        Polygon,
        PolygonMumbai,
        Arbitrum,
        ArbitrumSepolia,
        Optimism,
        OptimismSepolia,
        Unknown
    }

    /*//////////////////////////////////////////////////////////////
                            CHAIN ID MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the network enum from chain ID
    /// @param chainId The chain ID to map
    /// @return The corresponding Network enum value
    function getNetworkFromChainId(uint256 chainId) internal pure returns (Network) {
        if (chainId == 1) return Network.Ethereum;
        if (chainId == 11155111) return Network.Sepolia;
        if (chainId == 8453) return Network.Base;
        if (chainId == 84532) return Network.BaseSepolia;
        if (chainId == 137) return Network.Polygon;
        if (chainId == 80001) return Network.PolygonMumbai;
        if (chainId == 42161) return Network.Arbitrum;
        if (chainId == 421614) return Network.ArbitrumSepolia;
        if (chainId == 10) return Network.Optimism;
        if (chainId == 11155420) return Network.OptimismSepolia;
        return Network.Unknown;
    }

    /// @notice Get the current network based on block.chainid
    /// @return The current Network enum value
    function getCurrentNetwork() internal view returns (Network) {
        return getNetworkFromChainId(block.chainid);
    }

    /// @notice Get the network name as a string
    /// @param network The Network enum value
    /// @return The network name string
    function getNetworkName(Network network) internal pure returns (string memory) {
        if (network == Network.Ethereum) return "ethereum";
        if (network == Network.Sepolia) return "sepolia";
        if (network == Network.Base) return "base";
        if (network == Network.BaseSepolia) return "base-sepolia";
        if (network == Network.Polygon) return "polygon";
        if (network == Network.PolygonMumbai) return "polygon-mumbai";
        if (network == Network.Arbitrum) return "arbitrum";
        if (network == Network.ArbitrumSepolia) return "arbitrum-sepolia";
        if (network == Network.Optimism) return "optimism";
        if (network == Network.OptimismSepolia) return "optimism-sepolia";
        return "unknown";
    }

    /// @notice Get the current network name
    /// @return The current network name string
    function getCurrentNetworkName() internal view returns (string memory) {
        return getNetworkName(getCurrentNetwork());
    }

    /*//////////////////////////////////////////////////////////////
                          NETWORK CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if the current network is a testnet
    /// @return True if testnet, false otherwise
    function isTestnet() internal view returns (bool) {
        Network network = getCurrentNetwork();
        return network == Network.Sepolia ||
               network == Network.BaseSepolia ||
               network == Network.PolygonMumbai ||
               network == Network.ArbitrumSepolia ||
               network == Network.OptimismSepolia;
    }

    /// @notice Check if the current network is a mainnet
    /// @return True if mainnet, false otherwise
    function isMainnet() internal view returns (bool) {
        Network network = getCurrentNetwork();
        return network == Network.Ethereum ||
               network == Network.Base ||
               network == Network.Polygon ||
               network == Network.Arbitrum ||
               network == Network.Optimism;
    }

    /// @notice Get network-specific configuration
    /// @return fee The default fee for the network
    /// @return isTest Whether this is a test network
    function getNetworkConfig() internal view returns (uint256 fee, bool isTest) {
        isTest = isTestnet();

        // Adjust fees based on network (testnets can have lower fees)
        if (isTest) {
            fee = 0.00001 ether; // Lower fee for testnets
        } else {
            fee = 0.0001 ether; // Standard fee for mainnets
        }
    }

    /*//////////////////////////////////////////////////////////////
                             LOGGING HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Log current network information
    function logNetworkInfo() internal view {
        Network network = getCurrentNetwork();
        string memory name = getNetworkName(network);
        uint256 chainId = block.chainid;
        bool testnet = isTestnet();

        console.log("=== Network Information ===");
        console.log("Chain ID:", chainId);
        console.log("Network:", name);
        console.log("Is Testnet:", testnet ? "Yes" : "No");
        console.log("Is Mainnet:", isMainnet() ? "Yes" : "No");
    }
}
