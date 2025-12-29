// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPaynoteRegistry} from "./interfaces/IPaynoteRegistry.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title PaynoteRegistry
/// @author Paynote Protocol
/// @notice Minimal on-chain registry for attaching paid, verifiable references to transactions
/// @dev Events are the API - off-chain indexers consume NoteAttached events.
///      This is v1 of the protocol and is intentionally immutable (no proxy/upgrade patterns).
/// @custom:security-contact security@paynote.xyz
contract PaynoteRegistry is IPaynoteRegistry, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Fee required to attach a note (in wei)
    uint256 public fee;

    /// @notice Structure to store note details
    struct Note {
        bytes32 referenceHash;
        bytes32 category;
        string ipfsCID;
        uint256 timestamp;
    }

    /// @notice Tracks attached notes by (author, targetTxHash)
    /// @dev Mapping to Note struct for storing full note data
    mapping(address author => mapping(bytes32 targetTxHash => Note))
        private _notes;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Protocol version identifier
    string public constant VERSION = "1.0.0";

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new PaynoteRegistry
    /// @param initialFee The initial fee to attach a note (in wei)
    /// @param initialOwner The initial owner of the contract (receives fees, can update fee)
    constructor(
        uint256 initialFee,
        address initialOwner
    ) Ownable(initialOwner) {
        fee = initialFee;
        emit FeeUpdated(0, initialFee);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPaynoteRegistry
    function attachNote(
        bytes32 targetTxHash,
        bytes32 referenceHash,
        bytes32 category,
        string calldata ipfsCID
    ) external payable {
        // Validate fee payment
        if (msg.value < fee) revert InsufficientFee();

        // Validate inputs
        if (targetTxHash == bytes32(0)) revert InvalidTargetTxHash();
        if (referenceHash == bytes32(0)) revert InvalidReferenceHash();

        // Check for duplicate (one note per sender per transaction)
        if (_notes[msg.sender][targetTxHash].timestamp != 0)
            revert NoteAlreadyExists();

        // Record the note
        _notes[msg.sender][targetTxHash] = Note({
            referenceHash: referenceHash,
            category: category,
            ipfsCID: ipfsCID,
            timestamp: block.timestamp
        });

        // Emit the canonical event for off-chain indexers
        emit NoteAttached(
            msg.sender,
            targetTxHash,
            referenceHash,
            category,
            ipfsCID,
            block.timestamp
        );
    }

    /// @inheritdoc IPaynoteRegistry
    function hasNote(
        address author,
        bytes32 targetTxHash
    ) external view returns (bool) {
        return _notes[author][targetTxHash].timestamp != 0;
    }

    /// @inheritdoc IPaynoteRegistry
    function getNote(
        address author,
        bytes32 targetTxHash
    )
        external
        view
        returns (
            bytes32 referenceHash,
            bytes32 category,
            string memory ipfsCID,
            uint256 timestamp
        )
    {
        Note memory note = _notes[author][targetTxHash];
        return (
            note.referenceHash,
            note.category,
            note.ipfsCID,
            note.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update the fee required to attach a note
    /// @dev Only callable by contract owner
    /// @param newFee The new fee in wei
    function setFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = fee;
        fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    /// @notice Withdraw all collected fees to the owner
    /// @dev Only callable by contract owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = owner().call{value: balance}("");
        if (!success) revert WithdrawFailed();
    }

    /// @notice Withdraw a specific amount of fees to the owner
    /// @dev Only callable by contract owner
    /// @param amount The amount in wei to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        (bool success, ) = owner().call{value: amount}("");
        if (!success) revert WithdrawFailed();
    }
}
