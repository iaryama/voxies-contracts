# Voxies Contracts

<img alt="Solidity" src="https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black" /> <img alt="Solidity" src="https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white" />

## Overview

This repository contains the solidity smart contracts for project-voxies

## Prerequisites

-   git
-   node | npm

## Getting started

-   Clone the repository

```sh
git clone https://github.com/nonceblox/voxies-contracts
```

-   Navigate to `voxies-contracts` directory

```sh
cd voxies-contracts
```

-   Install dependencies

```sh
npm i
```

### Configure project
**Environment Configuration**
- Copy `.example.env` to `.env`
```sh
cp .example.env .env
```

**Private Key Configuration**
- Configure environment variables in `.env`
```
DEPLOYER_PRIVATE_KEY=<private-key>
EXPLORER_API_KEY=<api-key>
NFT_ENGINE_ADDRESS=<address-VoxiesNFTEnine.sol>
VOXEL_ADDRESS=<address-Voxel.sol>
```

## Run tasks

-   test

```sh
npm test
```

### Deploy to Testnet
```sh
npx hardhat run --network <your-network> scripts/deploy.js
```
## Verify smart contracts
### on Mumbai Testnet
```sh
npx hardhat verify --network mumbai DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```

### on Polygon Mainnet
```sh
npx hardhat verify --network polygon DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```



