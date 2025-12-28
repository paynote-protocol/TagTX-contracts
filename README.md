# Paynote Protocol

> Paynote is a minimal on-chain registry that lets transaction senders attach paid, verifiable references to Ethereum transactions via events.

[![CI](https://github.com/paynote-protocol/paynote-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/paynote-protocol/paynote-contracts/actions/workflows/ci.yml)

## Overview

Paynote provides an on-chain equivalent of bank transfer references / payment memos, enabling better reconciliation, auditing, analytics, and dispute resolution for on-chain payments.

### How It Works

1. **User sends a transaction** on any EVM chain (e.g., Base)
2. **User calls `attachNote()`** on the PaynoteRegistry, paying a small fee
3. **Contract emits `NoteAttached` event** with the reference hash
4. **Off-chain indexers** consume events and store/query the actual reference data

### Key Features

- **Event-driven API**: Events are the primary interface for off-chain tooling
- **Minimal on-chain storage**: Only stores a boolean per (author, txHash) pair
- **Spam resistance**: Small fee required to attach notes
- **Immutable**: No proxy or upgrade patterns in v1
- **Gas efficient**: ~39,000 gas to attach a note

## Contract API

### `attachNote(bytes32 targetTxHash, bytes32 referenceHash, bytes32 category)`

Attach a reference note to a target transaction.

| Parameter | Type | Description |
|-----------|------|-------------|
| `targetTxHash` | `bytes32` | Hash of the transaction being referenced |
| `referenceHash` | `bytes32` | Hash of the off-chain reference payload |
| `category` | `bytes32` | Category identifier (e.g., `keccak256("invoice")`) |

**Requirements:**
- Must pay the current fee (`msg.value >= fee()`)
- `targetTxHash` must not be zero
- `referenceHash` must not be zero
- Sender cannot have already attached a note for this transaction

### `hasNote(address author, bytes32 targetTxHash)`

Check if a note has been attached by a specific author for a transaction.

### `fee()`

Returns the current fee required to attach a note (in wei).

### Events

```solidity
event NoteAttached(
    address indexed author,
    bytes32 indexed targetTxHash,
    bytes32 referenceHash,
    bytes32 indexed category,
    uint256 timestamp
);

event FeeUpdated(uint256 oldFee, uint256 newFee);
```

## Usage Examples

### Attaching a Note (Solidity)

```solidity
import {IPaynoteRegistry} from "@paynote/contracts/interfaces/IPaynoteRegistry.sol";

contract MyContract {
    IPaynoteRegistry public paynote;

    function attachInvoiceReference(
        bytes32 targetTxHash,
        bytes32 invoiceHash
    ) external payable {
        paynote.attachNote{value: paynote.fee()}(
            targetTxHash,
            invoiceHash,
            keccak256("invoice")
        );
    }
}
```

### Attaching a Note (JavaScript/ethers.js)

```javascript
const paynote = new ethers.Contract(PAYNOTE_ADDRESS, PAYNOTE_ABI, signer);

const targetTxHash = "0x..."; // Previous transaction hash
const referenceHash = ethers.keccak256(ethers.toUtf8Bytes(JSON.stringify({
  invoiceId: "INV-2024-001",
  amount: "100.00",
  currency: "USDC"
})));
const category = ethers.keccak256(ethers.toUtf8Bytes("invoice"));

const fee = await paynote.fee();
await paynote.attachNote(targetTxHash, referenceHash, category, { value: fee });
```

### Querying Notes (Event Filtering)

```javascript
// Get all notes from a specific author
const filter = paynote.filters.NoteAttached(authorAddress, null, null);
const events = await paynote.queryFilter(filter);

// Get all notes for a specific transaction
const filter = paynote.filters.NoteAttached(null, targetTxHash, null);
const events = await paynote.queryFilter(filter);
```

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test -vvv

# Run with gas report
forge test --gas-report

# Run fuzz tests with more iterations
forge test --match-path "test/*.fuzz.t.sol" --fuzz-runs 10000

# Run invariant tests
forge test --match-path "test/*.invariant.t.sol"
```

### Format

```bash
forge fmt
```

### Coverage

```bash
forge coverage
```

## Deployment

### Configuration

1. Copy `.env.example` to `.env`
2. Fill in required values:
   - `PRIVATE_KEY`: Deployer wallet private key
   - `OWNER_ADDRESS`: Address that will own the contract
   - `BASESCAN_API_KEY`: For contract verification

### Deploy to Base Sepolia (Testnet)

```bash
source .env
forge script script/DeployPaynoteRegistry.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### Deploy to Base Mainnet

```bash
source .env
forge script script/DeployPaynoteRegistry.s.sol \
  --rpc-url $BASE_MAINNET_RPC_URL \
  --broadcast \
  --verify
```

## Security

### Design Considerations

- **Immutable v1**: No upgrade patterns; new features via new contract versions
- **Ownable2Step**: Two-step ownership transfer for safety
- **Custom errors**: Gas-efficient error handling
- **Minimal storage**: Only boolean flags, no complex data structures

### Known Limitations

- Anyone can attach a note to any transaction (authorization is off-chain)
- Reference content validation is off-chain
- No way to remove or update notes (by design)

### Audit Status

⚠️ This contract has not yet been audited. Use at your own risk.

## License

MIT

## Links

- [Website](https://paynote.xyz)
- [Documentation](https://docs.paynote.xyz)
- [GitHub](https://github.com/paynote-protocol/paynote-contracts)
