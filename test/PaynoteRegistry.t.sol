// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PaynoteRegistry} from "../src/PaynoteRegistry.sol";
import {IPaynoteRegistry} from "../src/interfaces/IPaynoteRegistry.sol";

/// @title PaynoteRegistry Unit Tests
/// @notice Comprehensive test coverage for the PaynoteRegistry contract
contract PaynoteRegistryTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mirror of IPaynoteRegistry.NoteAttached for emit testing
    event NoteAttached(
        address indexed author,
        bytes32 indexed targetTxHash,
        bytes32 referenceHash,
        bytes32 indexed category,
        uint256 timestamp
    );

    /// @dev Mirror of IPaynoteRegistry.FeeUpdated for emit testing
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PaynoteRegistry public registry;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    uint256 public constant INITIAL_FEE = 0.0001 ether;

    bytes32 public constant TARGET_TX_HASH = keccak256("target_tx_hash");
    bytes32 public constant REFERENCE_HASH = keccak256("reference_payload");
    bytes32 public constant CATEGORY_INVOICE = keccak256("invoice");
    bytes32 public constant CATEGORY_PAYROLL = keccak256("payroll");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        registry = new PaynoteRegistry(INITIAL_FEE, owner);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsInitialFee() public view {
        assertEq(registry.fee(), INITIAL_FEE);
    }

    function test_constructor_setsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_constructor_setsVersion() public view {
        assertEq(registry.VERSION(), "1.0.0");
    }

    function test_constructor_emitsFeeUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(0, INITIAL_FEE);
        new PaynoteRegistry(INITIAL_FEE, owner);
    }

    /*//////////////////////////////////////////////////////////////
                         ATTACH NOTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_attachNote_success() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_attachNote_emitsEvent() public {
        vm.prank(user);

        vm.expectEmit(true, true, true, true);
        emit NoteAttached(user, TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE, block.timestamp);

        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);
    }

    function test_attachNote_acceptsExactFee() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_attachNote_acceptsExcessFee() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE * 2}(
            TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE
        );

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
        assertEq(address(registry).balance, INITIAL_FEE * 2);
    }

    function test_attachNote_allowsZeroCategory() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(
            TARGET_TX_HASH,
            REFERENCE_HASH,
            bytes32(0) // Uncategorized note
        );

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_attachNote_multipleSendersForSameTx() public {
        // User 1 attaches note
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        // User 2 can also attach note to the same tx
        vm.prank(user2);
        registry.attachNote{value: INITIAL_FEE}(
            TARGET_TX_HASH, keccak256("different_reference"), CATEGORY_PAYROLL
        );

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
        assertTrue(registry.hasNote(user2, TARGET_TX_HASH));
    }

    function test_attachNote_sameSenderDifferentTxs() public {
        bytes32 txHash1 = keccak256("tx1");
        bytes32 txHash2 = keccak256("tx2");

        vm.startPrank(user);

        registry.attachNote{value: INITIAL_FEE}(txHash1, REFERENCE_HASH, CATEGORY_INVOICE);

        registry.attachNote{value: INITIAL_FEE}(txHash2, REFERENCE_HASH, CATEGORY_INVOICE);

        vm.stopPrank();

        assertTrue(registry.hasNote(user, txHash1));
        assertTrue(registry.hasNote(user, txHash2));
    }

    /*//////////////////////////////////////////////////////////////
                      ATTACH NOTE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_attachNote_revertsOnInsufficientFee() public {
        vm.prank(user);
        vm.expectRevert(IPaynoteRegistry.InsufficientFee.selector);
        registry.attachNote{value: INITIAL_FEE - 1}(
            TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE
        );
    }

    function test_attachNote_revertsOnZeroFee() public {
        vm.prank(user);
        vm.expectRevert(IPaynoteRegistry.InsufficientFee.selector);
        registry.attachNote{value: 0}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);
    }

    function test_attachNote_revertsOnZeroTargetTxHash() public {
        vm.prank(user);
        vm.expectRevert(IPaynoteRegistry.InvalidTargetTxHash.selector);
        registry.attachNote{value: INITIAL_FEE}(bytes32(0), REFERENCE_HASH, CATEGORY_INVOICE);
    }

    function test_attachNote_revertsOnZeroReferenceHash() public {
        vm.prank(user);
        vm.expectRevert(IPaynoteRegistry.InvalidReferenceHash.selector);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, bytes32(0), CATEGORY_INVOICE);
    }

    function test_attachNote_revertsOnDuplicate() public {
        vm.startPrank(user);

        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        vm.expectRevert(IPaynoteRegistry.NoteAlreadyExists.selector);
        registry.attachNote{value: INITIAL_FEE}(
            TARGET_TX_HASH, keccak256("different_reference"), CATEGORY_PAYROLL
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          HAS NOTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_hasNote_returnsFalseInitially() public view {
        assertFalse(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_hasNote_returnsTrueAfterAttach() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_hasNote_isolatesUsers() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
        assertFalse(registry.hasNote(user2, TARGET_TX_HASH));
    }

    /*//////////////////////////////////////////////////////////////
                          SET FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setFee_ownerCanSetFee() public {
        uint256 newFee = 0.001 ether;

        vm.prank(owner);
        registry.setFee(newFee);

        assertEq(registry.fee(), newFee);
    }

    function test_setFee_emitsFeeUpdated() public {
        uint256 newFee = 0.001 ether;

        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(INITIAL_FEE, newFee);

        vm.prank(owner);
        registry.setFee(newFee);
    }

    function test_setFee_canSetToZero() public {
        vm.prank(owner);
        registry.setFee(0);

        assertEq(registry.fee(), 0);

        // User can now attach note for free
        vm.prank(user);
        registry.attachNote{value: 0}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        assertTrue(registry.hasNote(user, TARGET_TX_HASH));
    }

    function test_setFee_revertsForNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        registry.setFee(0.001 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdraw_ownerCanWithdrawAll() public {
        // User attaches multiple notes
        vm.startPrank(user);
        registry.attachNote{value: INITIAL_FEE}(keccak256("tx1"), REFERENCE_HASH, CATEGORY_INVOICE);
        registry.attachNote{value: INITIAL_FEE}(keccak256("tx2"), REFERENCE_HASH, CATEGORY_INVOICE);
        vm.stopPrank();

        uint256 contractBalance = address(registry).balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        registry.withdraw();

        assertEq(address(registry).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
    }

    function test_withdrawAmount_ownerCanWithdrawPartial() public {
        // User attaches note
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        uint256 withdrawAmount = INITIAL_FEE / 2;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        registry.withdraw(withdrawAmount);

        assertEq(address(registry).balance, INITIAL_FEE - withdrawAmount);
        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount);
    }

    function test_withdraw_revertsForNonOwner() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        registry.withdraw();
    }

    function test_withdrawAmount_revertsForNonOwner() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        registry.withdraw(INITIAL_FEE);
    }

    /*//////////////////////////////////////////////////////////////
                       OWNERSHIP TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ownershipTransfer_twoStep() public {
        address newOwner = makeAddr("newOwner");

        // Step 1: Owner initiates transfer
        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // Owner is still the owner
        assertEq(registry.owner(), owner);
        assertEq(registry.pendingOwner(), newOwner);

        // Step 2: New owner accepts
        vm.prank(newOwner);
        registry.acceptOwnership();

        assertEq(registry.owner(), newOwner);
        assertEq(registry.pendingOwner(), address(0));
    }

    function test_ownershipTransfer_pendingOwnerCannotActUntilAccepted() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // Pending owner cannot set fee yet
        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", newOwner));
        registry.setFee(0.001 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function test_gas_attachNote() public {
        vm.prank(user);
        uint256 gasBefore = gasleft();
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for attachNote:", gasUsed);
        // Sanity check: should be under 50k gas
        assertLt(gasUsed, 50_000);
    }

    function test_gas_hasNote() public {
        vm.prank(user);
        registry.attachNote{value: INITIAL_FEE}(TARGET_TX_HASH, REFERENCE_HASH, CATEGORY_INVOICE);

        uint256 gasBefore = gasleft();
        registry.hasNote(user, TARGET_TX_HASH);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for hasNote:", gasUsed);
        // Sanity check: should be very cheap
        assertLt(gasUsed, 5000);
    }
}
