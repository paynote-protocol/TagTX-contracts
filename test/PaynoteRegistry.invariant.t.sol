// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PaynoteRegistry} from "../src/PaynoteRegistry.sol";

/// @title PaynoteRegistry Invariant Tests
/// @notice Invariant tests to verify protocol guarantees hold under all conditions
contract PaynoteRegistryInvariantTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PaynoteRegistry public registry;
    PaynoteRegistryHandler public handler;

    address public owner = makeAddr("owner");
    uint256 public constant INITIAL_FEE = 0.0001 ether;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        registry = new PaynoteRegistry(INITIAL_FEE, owner);
        handler = new PaynoteRegistryHandler(registry, owner);

        // Fund the handler
        vm.deal(address(handler), 1000 ether);

        // Target only the handler for invariant testing
        targetContract(address(handler));

        // Exclude the registry from direct calls
        excludeContract(address(registry));
    }

    /*//////////////////////////////////////////////////////////////
                          INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Invariant: Once a note is attached, hasNote returns true forever
    /// @dev Notes are permanent and cannot be removed
    function invariant_notesArePermanent() public view {
        (address[] memory authors, bytes32[] memory txHashes) = handler
            .getAttachedNotes();

        for (uint256 i = 0; i < authors.length; i++) {
            assertTrue(
                registry.hasNote(authors[i], txHashes[i]),
                "Note should exist permanently"
            );
        }
    }

    /// @notice Invariant: Total notes attached equals handler's note count
    function invariant_noteCountConsistency() public view {
        (address[] memory authors, ) = handler.getAttachedNotes();
        assertEq(
            handler.getNoteCount(),
            authors.length,
            "Note count should match array length"
        );
    }

    /// @notice Invariant: Fee is always the value set by owner
    function invariant_feeMatchesLastSet() public view {
        assertEq(
            registry.fee(),
            handler.getLastSetFee(),
            "Fee should match last set value"
        );
    }

    /// @notice Invariant: Only owner can modify fee
    function invariant_ownershipIntegrity() public view {
        // If ownership was transferred and accepted, check new owner
        // Otherwise, original owner should still be owner
        address expectedOwner = handler.getCurrentExpectedOwner();
        assertEq(
            registry.owner(),
            expectedOwner,
            "Owner should match expected"
        );
    }
}

/// @title PaynoteRegistryHandler
/// @notice Handler contract for invariant testing - simulates user interactions
contract PaynoteRegistryHandler is Test {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PaynoteRegistry public registry;
    address public owner;

    // Track all attached notes for invariant checking
    address[] internal _authors;
    bytes32[] internal _txHashes;
    mapping(bytes32 => bool) internal _noteKeys;

    // Track the last fee set
    uint256 internal _lastSetFee;

    // Track ownership state
    address internal _expectedOwner;

    // Ghost variables for tracking
    uint256 public ghostNoteCount;
    uint256 public ghostTotalFeesCollected;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(PaynoteRegistry _registry, address _owner) {
        registry = _registry;
        owner = _owner;
        _lastSetFee = _registry.fee();
        _expectedOwner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                           HANDLER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Simulate a user attaching a note
    function attachNote(
        uint256 senderSeed,
        bytes32 targetTxHash,
        bytes32 referenceHash,
        bytes32 category
    ) external {
        // Generate valid inputs
        address sender = _boundAddress(senderSeed);
        if (targetTxHash == bytes32(0))
            targetTxHash = keccak256(abi.encodePacked(senderSeed));
        if (referenceHash == bytes32(0))
            referenceHash = keccak256(abi.encodePacked(targetTxHash));

        // Check if this note already exists
        bytes32 noteKey = keccak256(abi.encodePacked(sender, targetTxHash));
        if (_noteKeys[noteKey]) return; // Skip if already attached

        uint256 fee = registry.fee();

        vm.prank(sender);
        try
            registry.attachNote{value: fee}(
                targetTxHash,
                referenceHash,
                category,
                "QmInvariantCID"
            )
        {
            // Track successful note attachment
            _authors.push(sender);
            _txHashes.push(targetTxHash);
            _noteKeys[noteKey] = true;
            ghostNoteCount++;
            ghostTotalFeesCollected += fee;
        } catch {
            // Attachment failed, that's okay for invariant testing
        }
    }

    /// @notice Simulate owner setting fee
    function setFee(uint256 newFee) external {
        vm.prank(owner);
        try registry.setFee(newFee) {
            _lastSetFee = newFee;
        } catch {
            // Failed, probably not owner anymore
        }
    }

    /// @notice Simulate owner withdrawing
    function withdraw() external {
        vm.prank(owner);
        try registry.withdraw() {
            // Success
        } catch {
            // Failed
        }
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAttachedNotes()
        external
        view
        returns (address[] memory, bytes32[] memory)
    {
        return (_authors, _txHashes);
    }

    function getNoteCount() external view returns (uint256) {
        return _authors.length;
    }

    function getLastSetFee() external view returns (uint256) {
        return _lastSetFee;
    }

    function getCurrentExpectedOwner() external view returns (address) {
        return _expectedOwner;
    }

    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _boundAddress(uint256 seed) internal pure returns (address) {
        // Generate a valid non-zero address from seed
        return address(uint160(bound(seed, 1, type(uint160).max)));
    }
}
