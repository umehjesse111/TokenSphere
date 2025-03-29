# TokenSphere

A simple, lightweight token management system built with Clarity for the Stacks blockchain ecosystem.

## Overview

TokenSphere is a customizable token creation and management system that allows administrators to create new tokens with custom parameters, transfer tokens between users, and manage token supply through minting and burning operations.

## Features

- **Token Creation**: Create new tokens with custom name, ticker symbol, and initial supply
- **Token Transfers**: Send tokens between users securely
- **Token Burning**: Reduce token circulation by destroying tokens
- **Balance Checking**: View token holdings for any address
- **Token Metadata**: Access information about the token's properties

## Functions

### Administrative Functions

- `create-token`: Create a new token with specified parameters (admin only)

### User Functions

- `send-tokens`: Transfer tokens to another address
- `destroy-tokens`: Burn tokens to reduce supply
- `check-balance`: View token balance for any address
- `get-token-info`: Retrieve token metadata (name, symbol, and circulation)

## Error Codes

- `ERR_UNAUTHORIZED (u100)`: Caller is not the contract administrator
- `ERR_INVALID_AMOUNT (u101)`: Requested amount exceeds limits or is invalid
- `ERR_BALANCE_LOW (u102)`: Insufficient balance for requested operation
- `ERR_TOKEN_ALREADY_EXISTS (u103)`: A token has already been created in this contract

## Supply Limits

The maximum token supply is capped at 1,000,000 units to prevent inflation.

## Setup and Deployment

1. Install the [Clarinet](https://github.com/hirosystems/clarinet) development environment
2. Clone this repository
3. Deploy using Clarinet or directly to the Stacks blockchain

## Security Considerations

- Only the contract deployer has administrative privileges
- All functions include appropriate balance and permission checks
- Token operations are atomic and secure

