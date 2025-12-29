// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPaynoteRegistry
/// @author Paynote Protocol
/// @notice Interface for the Paynote reference registry
/// @dev Events are the primary API - off-chain indexers consume NoteAttached events
interface IPaynoteRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a note is attached to a transaction
    /// @param author The address that attached the note (must be original tx sender)
    /// @param targetTxHash The hash of the transaction being referenced
    /// @param referenceHash Hash of the off-chain reference payload
    /// @param category Category identifier for the reference type
    /// @param ipfsCID IPFS content identifier for the note content
    /// @param timestamp Block timestamp when the note was attached
    event NoteAttached(
        address indexed author,
        bytes32 indexed targetTxHash,
        bytes32 referenceHash,
        bytes32 indexed category,
        string ipfsCID,
        uint256 timestamp
    );

    /// @notice Emitted when the fee is updated
    /// @param oldFee The previous fee amount
    /// @param newFee The new fee amount
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when msg.value is less than the required fee
    error InsufficientFee();

    /// @notice Thrown when attempting to attach a duplicate note
    error NoteAlreadyExists();

    /// @notice Thrown when targetTxHash is zero
    error InvalidTargetTxHash();

    /// @notice Thrown when referenceHash is zero
    error InvalidReferenceHash();

    /// @notice Thrown when ETH withdrawal fails
    error WithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Attach a reference note to a target transaction
    /// @dev Requires payment of the current fee. Emits NoteAttached event.
    /// @param targetTxHash The transaction hash to attach a note to
    /// @param referenceHash Hash of the off-chain reference payload
    /// @param category Category identifier (e.g., keccak256("invoice"))
    /// @param ipfsCID IPFS content identifier for the note content
    function attachNote(
        bytes32 targetTxHash,
        bytes32 referenceHash,
        bytes32 category,
        string calldata ipfsCID
    ) external payable;

    /// @notice Get the current fee required to attach a note
    /// @return The fee amount in wei
    function fee() external view returns (uint256);

    /// @notice Check if a note has already been attached by an author for a transaction
    /// @param author The address that attached the note
    /// @param targetTxHash The transaction hash to check
    /// @return True if a note exists, false otherwise
    function hasNote(
        address author,
        bytes32 targetTxHash
    ) external view returns (bool);

    /// @notice Get the details of a note attached by an author for a transaction
    /// @param author The address that attached the note
    /// @param targetTxHash The transaction hash to check
    /// @return referenceHash Hash of the off-chain reference payload
    /// @return category Category identifier for the reference type
    /// @return ipfsCID IPFS content identifier for the note content
    /// @return timestamp Block timestamp when the note was attached
    function getNote(
        address author,
        bytes32 targetTxHash
    ) external view returns (
        bytes32 referenceHash,
        bytes32 category,
        string memory ipfsCID,
        uint256 timestamp
    );

    /// @notice Get the protocol version
    /// @return The version string
    function VERSION() external view returns (string memory);
}
