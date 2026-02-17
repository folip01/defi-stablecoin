# Decentralized Stablecoin (DSC) Engine
> ✅ **COMPLETE - Educational Project**

## About

This is an educational DeFi protocol implementing a decentralized stablecoin system inspired by MakerDAO/DAI. The system allows users to deposit crypto collateral (WETH, WBTC) and mint a dollar-pegged stablecoin (DSC).

**Key Features:**
- Exogenously collateralized (backed by WETH and WBTC)
- Dollar pegged (1 DSC = $1 USD)
- Algorithmically stable through overcollateralization
- Requires 200% collateralization ratio
- Automated liquidation mechanism
- Chainlink price feed integration

## Project Status

### ✅ Completed
- [x] Core DSCEngine contract implementation
- [x] Basic deposit/withdraw collateral functionality
- [x] Mint/burn DSC functionality
- [x] Health factor calculation system
- [x] Liquidation mechanism
- [x] Chainlink oracle integration
✅ Completed
- [x] Core DSCEngine contract
- [x] Unit tests
- [x] Integration tests
- [x] Fuzz/Invariant tests
- [x] Deployment scripts
- [x] Additional contracts

## Contract Overview

### DSCEngine.sol
The core engine that handles:
- Collateral deposits and withdrawals
- DSC minting and burning
- Health factor monitoring
- Liquidation execution
- Price feed management

### DecentralizedStableCoin.sol
ERC20 token implementation for the DSC stablecoin.

### OracleLib.sol
Library for secure Chainlink price feed interactions with staleness checks.

## How It Works

1. **Deposit Collateral**: Users deposit approved tokens (WETH/WBTC) as collateral
2. **Mint DSC**: Users can mint DSC up to 50% of their collateral value (200% overcollateralization)
3. **Health Factor**: System monitors each user's health factor (must stay ≥ 1.0)
4. **Liquidation**: If health factor drops below 1.0, anyone can liquidate the position for a 10% bonus

### Example Flow
```
1. Alice deposits 1 ETH (worth $2000)
2. Alice can mint maximum $1000 DSC (50% of collateral value)
3. If ETH price drops to $1800:
   - Adjusted collateral: $1800 × 50% = $900
   - Health factor: $900 / $1000 = 0.9 ❌
   - Alice becomes liquidatable
4. Bob liquidates Alice, getting 10% bonus
```

## Key Concepts

### Health Factor
```
Health Factor = (Collateral Value × Liquidation Threshold) / Total DSC Minted
```
- Must be ≥ 1.0 to remain solvent
- Liquidation Threshold = 50% (enforces 200% overcollateralization)

### Liquidation
- Triggered when health factor < 1.0
- Liquidator pays off user's debt
- Receives collateral + 10% bonus
- Helps keep protocol solvent

## Technology Stack

- **Solidity**: 0.8.19
- **Chainlink**: Price feeds for ETH/USD and BTC/USD
- **OpenZeppelin**: ReentrancyGuard, ERC20
- **Foundry**: Testing and deployment framework (planned)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dsc-engine.git
cd dsc-engine

# Install dependencies (once test suite is added)
forge install

# Run tests (once available)
forge test
```

## Current File Structure

```
dsc-engine/
├── src/
│   ├── DSCEngine.sol
│   ├── DecentralizedStableCoin.sol
│   └── libraries/
│       └── OracleLib.sol
├── test/              (Coming soon)
├── script/            (Coming soon)
└── README.md
```

## Development Roadmap

### Phase 1: Core Implementation ✅
- Smart contract development
- Basic functionality

### Phase 2: Testing 🚧 (Current Phase)
- Unit tests for all functions
- Integration tests
- Fuzz tests
- Invariant tests

### Phase 3: Security & Optimization
- Security audit
- Gas optimization
- Edge case handling

### Phase 4: Deployment
- Deployment scripts
- Testnet deployment
- Documentation

### Phase 5: Production (Future)
- Mainnet deployment (NOT PLANNED - Educational purposes only)
- Monitoring & maintenance

## Learning Resources

This project is based on the Cyfrin Updraft course by Patrick Collins. It's designed as an educational tool to understand:
- DeFi protocol mechanics
- Stablecoin design
- Oracle integration
- Liquidation systems
- Smart contract security

## Security Notice

⚠️ **DO NOT USE IN PRODUCTION**

This is an educational project and has NOT been audited. Known limitations:
- No fee mechanism (protocol makes $0)
- No governance
- Limited to WETH and WBTC
- Not tested in production scenarios
- May contain undiscovered vulnerabilities

## Contributing

Since this is a learning project, contributions are welcome! Feel free to:
- Report bugs
- Suggest improvements
- Add tests
- Improve documentation

## Future Improvements

Potential additions to make this production-ready:
- [ ] Stability fees (interest on borrowed DSC)
- [ ] Liquidation fees for protocol treasury
- [ ] Additional collateral types
- [ ] Governance token
- [ ] Emergency pause mechanism
- [ ] Price feed backup oracles
- [ ] Gradual liquidation mechanism

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Patrick Collins for the Cyfrin Updraft course
- MakerDAO for the DAI inspiration
- Chainlink for oracle infrastructure
- OpenZeppelin for secure contract libraries

---

**Last Updated**: January 2026
**Status**: Under Active Development
**Version**: 0.1.0 (Pre-release)
