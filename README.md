# Mensari STX Yield Vault

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Clarity](https://img.shields.io/badge/Clarity-2.0-blue.svg)](https://clarity-lang.org/)
[![Stacks](https://img.shields.io/badge/Stacks-2.0-orange.svg)](https://stacks.co/)
[![Build Status](https://img.shields.io/github/actions/workflow/status/kramu39/mensari-staking-vault/ci.yml)](https://github.com/kramu39/mensari-staking-vault/actions)
[![Coverage](https://img.shields.io/codecov/c/github/kramu39/mensari-staking-vault)](https://codecov.io/gh/kramu39/mensari-staking-vault)

A decentralized staking vault smart contract built on the Stacks blockchain using Clarity. Users can stake STX (Stacks tokens) for various lock periods and earn USDCx rewards with boosted multipliers based on their commitment duration.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## Overview

The Mensari STX Yield Vault is a non-custodial staking protocol that allows users to lock their STX tokens for predetermined periods in exchange for USDCx yield rewards. The longer the lock period, the higher the reward multiplier, incentivizing long-term participation in the Stacks ecosystem.

This contract implements a reward distribution mechanism where vault owners can add USDCx rewards that are proportionally distributed to stakers based on their deposited STX amount and lock period multiplier.

## Features

### 🔒 Flexible Lock Periods
- 60 days (1x multiplier)
- 180 days (1.2x multiplier)
- 360 days (1.4x multiplier)
- 900 days (1.75x multiplier)
- 1800 days (2.2x multiplier)

### 💰 Reward System
- Pro-rata reward distribution based on STX deposits
- Lock period multipliers for enhanced yields
- Manual reward addition by vault owner
- Accrued rewards tracking per user

### 🛡️ Security Features
- Owner-controlled emergency drain function
- Pause/unpause mechanism for maintenance
- Comprehensive input validation
- Non-custodial design (users retain control)

### 📊 Transparency
- Real-time deposit and reward tracking
- Event logging for all major actions
- Read-only functions for public data access

## How It Works

1. **Deposit**: Users deposit STX and select a lock period. The contract calculates their share of future rewards.

2. **Reward Distribution**: The vault owner adds USDCx rewards, which are distributed proportionally to all stakers based on their STX balance.

3. **Reward Accrual**: Rewards accumulate over time. The longer the lock period, the higher the multiplier applied to rewards.

4. **Withdrawal**: After the lock period expires, users can withdraw their STX plus accrued USDCx rewards (with multiplier applied).

5. **Emergency Functions**: The owner can pause operations, drain funds in emergencies, or transfer ownership.

## Architecture

### Core Components

- **Deposit Management**: Tracks user deposits, lock periods, and deposit timestamps
- **Reward System**: Implements reward-per-token mechanism with precision handling
- **Multiplier Logic**: Applies lock-period based multipliers to rewards
- **Access Control**: Owner-only functions for reward addition and emergency operations

### Data Structures

```clarity
;; User deposits and metadata
(define-map deposits principal uint)
(define-map deposit-time principal uint)
(define-map lock-period principal uint)

;; Reward tracking
(define-map reward-debt principal uint)
(define-map accrued-rewards principal uint)

;; Global state
(define-data-var total-deposited uint u0)
(define-data-var reward-per-token uint u0)
```

### Reward Calculation

The reward system uses a "reward per token" model:

```
reward_per_token += (new_rewards * PRECISION) / total_deposited
user_pending = (user_balance * reward_per_token / PRECISION) - user_debt
final_reward = user_pending * multiplier / 100
```

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) (latest version)
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Rust](https://rustup.rs/) (for Clarinet)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/kramu39/mensari-staking-vault.git
cd mensari-staking-vault
```

2. Install dependencies:
```bash
npm install
```

3. Install Clarinet (if not already installed):
```bash
curl -L https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-linux-x64.tar.gz | tar xz
sudo mv clarinet /usr/local/bin/
```

## Usage

### Development Environment

Start the Clarinet console:
```bash
clarinet console
```

### Testing

Run the test suite:
```bash
npm test
```

Run tests with coverage:
```bash
npm run test:report
```

Watch mode for development:
```bash
npm run test:watch
```

### Deployment

1. Configure your deployment settings in `Clarinet.toml`

2. Deploy to testnet:
```bash
clarinet deployments generate --devnet
clarinet deployments deploy
```

3. For mainnet deployment, update the configuration and use:
```bash
clarinet deployments generate --mainnet
clarinet deployments deploy
```

## API Documentation

### Public Functions

#### `deposit (amount uint) (lock-choice uint)`

Deposits STX into the vault with a specified lock period.

**Parameters:**
- `amount`: Amount of STX to deposit (in microSTX)
- `lock-choice`: Lock period (must be one of the predefined constants)

**Returns:** `(ok true)` on success

**Events:** `{event: "deposit", user: principal, amount: uint, lock: uint}`

#### `withdraw ()`

Withdraws deposited STX and claims accrued USDCx rewards after lock period expires.

**Returns:** `(ok {withdrawn: uint, principal: uint, rewards: uint})`

**Events:** `{event: "withdraw", user: principal, principal: uint, rewards: uint}`

#### `add-rewards (amount uint)`

Adds USDCx rewards to the vault (owner only).

**Parameters:**
- `amount`: Amount of USDCx to add

**Returns:** `(ok true)` on success

**Events:** `{event: "add-rewards", amount: uint}`

### Owner Functions

#### `emergency-drain ()`

Drains all STX from the contract to the owner (emergency only).

#### `set-owner (new-owner principal)`

Transfers ownership to a new address.

#### `pause () / unpause ()`

Pauses or unpauses contract operations.

### Read-Only Functions

#### `get-user-deposit (user principal)`
Returns the user's deposited STX amount.

#### `get-user-lock-period (user principal)`
Returns the user's lock period.

#### `get-total-deposited ()`
Returns total STX deposited in the vault.

#### `get-user-rewards (user principal)`
Returns the user's accrued rewards.

#### `get-owner ()`
Returns the current owner address.

#### `get-paused ()`
Returns pause status.

### Constants

- `LOCK_60DAYS`: 8640 blocks
- `LOCK_180DAYS`: 25920 blocks
- `LOCK_360DAYS`: 51840 blocks
- `LOCK_900DAYS`: 129600 blocks
- `LOCK_1800DAYS`: 259200 blocks

### Multipliers

- 60 days: 100% (1x)
- 180 days: 120% (1.2x)
- 360 days: 140% (1.4x)
- 900 days: 175% (1.75x)
- 1800 days: 220% (2.2x)

## Testing

The project includes comprehensive unit tests covering:

- Deposit functionality with various lock periods
- Reward distribution and accrual
- Withdrawal mechanics and lock enforcement
- Owner functions and access control
- Edge cases and error handling

Tests are written using Vitest and the Clarinet SDK.

## Deployment

### Testnet

Deploy to Stacks testnet for testing:

```bash
clarinet deployments generate --testnet
clarinet deployments deploy
```

### Mainnet

For production deployment:

1. Update `Clarinet.toml` with mainnet settings
2. Generate deployment plan:
```bash
clarinet deployments generate --mainnet
```
3. Review and deploy:
```bash
clarinet deployments deploy
```

## Security

### Audit Status

This contract has been designed with security best practices in mind. However, it is recommended to conduct a professional security audit before mainnet deployment.

### Known Considerations

- Owner has significant control (reward addition, emergency functions)
- Rewards depend on owner adding USDCx tokens
- Lock periods are enforced by block height
- Contract uses as-contract pattern for token transfers

### Emergency Procedures

- Owner can pause operations immediately
- Emergency drain function available for critical situations
- Ownership transfer mechanism for succession planning

## Contributing

We welcome contributions to the Mensari STX Yield Vault project!

### Development Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and add tests
4. Ensure all tests pass: `npm test`
5. Submit a pull request

### Guidelines

- Follow Clarity best practices
- Add comprehensive tests for new features
- Update documentation for API changes
- Use clear commit messages

### Code Style

- Use 2-space indentation for Clarity code
- Follow conventional naming conventions
- Add comments for complex logic

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The authors are not responsible for any financial losses incurred through the use of this contract.

## Contact

For questions or support, please open an issue on GitHub or contact the maintainers.

---

*Built with ❤️ on the Stacks blockchain*