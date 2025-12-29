// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PaynoteRegistry} from "../src/PaynoteRegistry.sol";
import {IPaynoteRegistry} from "../src/interfaces/IPaynoteRegistry.sol";

/// @title PaynoteRegistry Fuzz Tests
/// @notice Fuzz tests to verify contract behavior with random inputs
contract PaynoteRegistryFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PaynoteRegistry public registry;

    address public owner = makeAddr("owner");

    uint256 public constant INITIAL_FEE = 0.0001 ether;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        registry = new PaynoteRegistry(INITIAL_FEE, owner);
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test: attachNote with random valid inputs
    function testFuzz_attachNote_validInputs(
        address sender,
        bytes32 targetTxHash,
        bytes32 referenceHash,
        bytes32 category,
        string calldata ipfsCID
    ) public {
        // Bound inputs to valid values
        vm.assume(sender != address(0));
        vm.assume(targetTxHash != bytes32(0));
        vm.assume(referenceHash != bytes32(0));
        vm.assume(bytes(ipfsCID).length > 0 && bytes(ipfsCID).length <= 100); // Reasonable IPFS CID length

        vm.deal(sender, 1 ether);

        vm.prank(sender);
        registry.attachNote{value: INITIAL_FEE}(
            targetTxHash,
            referenceHash,
            category,
            ipfsCID
        );

        assertTrue(registry.hasNote(sender, targetTxHash));
    }

    /// @notice Fuzz test: attachNote with random fee amounts above minimum
    function testFuzz_attachNote_excessFee(uint256 extraFee) public {
        extraFee = bound(extraFee, 0, 10 ether);
        uint256 totalFee = INITIAL_FEE + extraFee;

        address sender = makeAddr("sender");
        vm.deal(sender, totalFee);

        bytes32 targetTxHash = keccak256("target");
        bytes32 referenceHash = keccak256("reference");

        vm.prank(sender);
        registry.attachNote{value: totalFee}(
            targetTxHash,
            referenceHash,
            keccak256("category"),
            "QmTestCID"
        );

        assertTrue(registry.hasNote(sender, targetTxHash));
        assertEq(address(registry).balance, totalFee);
    }

    /// @notice Fuzz test: hasNote returns correct values for random addresses
    function testFuzz_hasNote_isolation(
        address sender1,
        address sender2,
        bytes32 targetTxHash
    ) public {
        vm.assume(sender1 != address(0));
        vm.assume(sender2 != address(0));
        vm.assume(sender1 != sender2);
        vm.assume(targetTxHash != bytes32(0));

        vm.deal(sender1, 1 ether);

        // Only sender1 attaches a note
        vm.prank(sender1);
        registry.attachNote{value: INITIAL_FEE}(
            targetTxHash,
            keccak256("reference"),
            keccak256("category"),
            "QmTestCID"
        );

        // sender1 has the note, sender2 does not
        assertTrue(registry.hasNote(sender1, targetTxHash));
        assertFalse(registry.hasNote(sender2, targetTxHash));
    }

    /// @notice Fuzz test: setFee with random values
    function testFuzz_setFee(uint256 newFee) public {
        vm.prank(owner);
        registry.setFee(newFee);

        assertEq(registry.fee(), newFee);
    }

    /// @notice Fuzz test: attachNote reverts with insufficient fee
    function testFuzz_attachNote_insufficientFee(uint256 paidFee) public {
        paidFee = bound(paidFee, 0, INITIAL_FEE - 1);

        address sender = makeAddr("sender");
        vm.deal(sender, INITIAL_FEE);

        vm.prank(sender);
        vm.expectRevert(IPaynoteRegistry.InsufficientFee.selector);
        registry.attachNote{value: paidFee}(
            keccak256("target"),
            keccak256("reference"),
            keccak256("category"),
            "QmTestCID"
        );
    }

    /// @notice Fuzz test: multiple notes from same sender to different txs
    function testFuzz_attachNote_multipleTxs(
        address sender,
        bytes32[5] memory targetTxHashes
    ) public {
        vm.assume(sender != address(0));

        // Ensure all tx hashes are unique and non-zero
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(targetTxHashes[i] != bytes32(0));
            for (uint256 j = i + 1; j < 5; j++) {
                vm.assume(targetTxHashes[i] != targetTxHashes[j]);
            }
        }

        vm.deal(sender, 10 ether);
        vm.startPrank(sender);

        for (uint256 i = 0; i < 5; i++) {
            registry.attachNote{value: INITIAL_FEE}(
                targetTxHashes[i],
                keccak256(abi.encodePacked("reference", i)),
                keccak256("category"),
                "QmTestCID"
            );
        }

        vm.stopPrank();

        // All notes should exist
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(registry.hasNote(sender, targetTxHashes[i]));
        }
    }

    /// @notice Fuzz test: withdraw works for any balance
    function testFuzz_withdraw(uint256 numNotes) public {
        numNotes = bound(numNotes, 1, 100);

        address sender = makeAddr("sender");
        vm.deal(sender, numNotes * INITIAL_FEE);

        vm.startPrank(sender);
        for (uint256 i = 0; i < numNotes; i++) {
            registry.attachNote{value: INITIAL_FEE}(
                keccak256(abi.encodePacked("tx", i)),
                keccak256(abi.encodePacked("ref", i)),
                keccak256("category"),
                "QmTestCID"
            );
        }
        vm.stopPrank();

        uint256 expectedBalance = numNotes * INITIAL_FEE;
        assertEq(address(registry).balance, expectedBalance);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        registry.withdraw();

        assertEq(address(registry).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + expectedBalance);
    }

    /// @notice Fuzz test: constructor with random initial values
    function testFuzz_constructor(
        uint256 initialFee,
        address initialOwner
    ) public {
        vm.assume(initialOwner != address(0));

        PaynoteRegistry newRegistry = new PaynoteRegistry(
            initialFee,
            initialOwner
        );

        assertEq(newRegistry.fee(), initialFee);
        assertEq(newRegistry.owner(), initialOwner);
    }
}
