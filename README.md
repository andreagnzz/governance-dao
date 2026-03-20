# Governance DAO

On-chain DAO governance system built with Solidity, OpenZeppelin v5.x, and Foundry.

## Architecture

```
GovernanceToken (ERC20Votes)
        │
        ▼
   MyGovernor ──────► MyTimelock
  (proposals,        (execution delay,
   voting)            role management)
```

1. **GovernanceToken** — ERC20 token with voting power (ERC20Votes + ERC20Permit). Token holders must delegate (including to themselves) to activate voting power.
2. **MyGovernor** — Governor contract handling proposals, voting, and quorum checks. Proposals that pass are queued in the timelock.
3. **MyTimelock** — TimelockController enforcing a delay before execution. Ensures the community can react to passed proposals.

## Governance Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Voting Delay | 7,200 blocks (~24h) | Time between proposal creation and voting start |
| Voting Period | 50,400 blocks (~7 days) | Duration of the voting window |
| Proposal Threshold | 0 | Minimum tokens required to create a proposal |
| Quorum | 4% | Percentage of total supply needed for a valid vote |
| Timelock Delay | 3,600 seconds (1h) | Minimum delay before executing a queued proposal |
| Initial Supply | 1,000,000 GOV | Total token supply minted at deployment |

## Installation

```bash
git clone <repo-url>
cd governance-dao
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test -vvv
```

## Deploy

### Local (Anvil)

```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
cp .env.example .env
# Edit .env with an Anvil private key (e.g., 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
source .env
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### Sepolia Testnet

```bash
cp .env.example .env
# Edit .env with your Sepolia RPC URL, private key, and Etherscan API key
source .env
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Using Tally for Governance UI

[Tally](https://www.tally.xyz/) provides a web interface for interacting with your DAO.

### Step-by-step Guide

1. **Add your DAO** — Go to [tally.xyz](https://www.tally.xyz/), click "Add a DAO", select the network (Sepolia), and paste your MyGovernor contract address.
2. **Create a Proposal** — Connect your wallet, click "Create Proposal", define the target contract, function call, and description.
3. **Vote** — During the voting period, token holders can vote For, Against, or Abstain directly on the proposal page.
4. **Queue** — Once the proposal succeeds, click "Queue" to submit it to the timelock.
5. **Execute** — After the timelock delay passes, click "Execute" to run the proposal on-chain.

## Project Structure

```
governance-dao/
├── src/
│   ├── GovernanceToken.sol    # ERC20 + Votes + Permit
│   ├── MyGovernor.sol         # Governor with all extensions
│   └── MyTimelock.sol         # TimelockController wrapper
├── script/
│   └── Deploy.s.sol           # Deployment script
├── test/
│   └── GovernanceTest.t.sol   # Full test suite (10 tests)
├── foundry.toml               # Foundry configuration
├── remappings.txt             # Import remappings
├── .env.example               # Environment variables template
└── LICENSE                    # MIT License
```

## Resources

- [OpenZeppelin Contracts v5.x](https://docs.openzeppelin.com/contracts/5.x/)
- [OpenZeppelin GitHub](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Tally](https://www.tally.xyz/)
- [Foundry Book](https://book.getfoundry.sh/)
