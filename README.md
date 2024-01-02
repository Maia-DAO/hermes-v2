# Hermes V2 Contracts

<!--
Badges provide a quick visual way to convey various information about your project. Below are several common types of badges. Feel free to uncomment, remove, or add new badges as needed for your project. Make sure to update the links so they point to the correct sources relevant to your project.

- Version: Shows the current version of your project based on the latest release.
- Test CI: Displays the status of your continuous integration testing.
- Lint: Shows the status of your code linting process.
- Code Coverage: Indicates the percentage of your code covered by tests.
- License: Shows the type of license your project is under.
- Docs: Links to your project's documentation.
- Discord: Provides a quick link to join your Discord server.
- Discussions: (Optional) If you use GitHub Discussions, this badge links to that section.
- JS Library: (Optional) If your project includes a JavaScript library, use this badge to link to it.

Remember to replace 'Maia-DAO/foundry-template' with your repository's path and update other relevant links to reflect your project's resources.
-->

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Lint][lint-badge]][lint-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![Solidity][solidity-shield]][ci-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discord][discord-badge]][discord-link]
<!-- [![Discussions][discussions-badge]][discussions-link] -->
<!-- [![JS Library][js-library-badge]][js-library-link] -->

In this repo you will find the contracts for the Hermes V2 reward system.

## Contributing

If you’re interested in contributing please see our [contribution guidelines](./CONTRIBUTING.md)! This includes instructions on how to compile and run tests locally.

## Documentation

A more detailed description of the project can be found in the [documentation](https://v2-docs.maiadao.io/protocols/Hermes/introduction).

## Architecture

The system is composed of the following directories:
- `erc-20`: Contains the ERC20 contracts used by the system.
- `erc-4626`: Contains the ERC4626 contracts used by the system.
- `gauges`: Contains the contracts that handle the creation of liquidity provider incentives.
- `hermes`: Contains the contracts that make up the Hermes and bHermes token.
- `rewards`: Contains the contracts that handle the distribution of rewards.
- `uni-v3-staker`: Contains the contracts that handle the distribution of rewards for Uniswap V3 LPs.

## Repository Structure

All contracts are held within the `./src` folder.

Note that helper contracts used by tests are held in the `./test/utils` subfolder within the contracts folder. Any new test helper contracts should be added there and all foundry tests are in the `./test` folder.

```ml
src
├── erc-20
│   ├── ERC20Boost - "ERC20 with an embedded attachment mechanism to keep track of boost allocations to gauges"
│   ├── ERC20Gauges - "ERC20 with an embedded "Gauge" style vote with liquid weights"
│   ├── ERC20MultiVotes - "ERC20 Multi-Delegation Voting contract"
│   └── interfaces
│       ├── Errors - "Shared Errors Interface"
│       ├── IERC20Boost - "ERC20Boost Interface"
│       ├── IERC20Gauges - "ERC20Gauges Interface"
│       └── IERC20MultiVotes - "ERC20MultiVotes Interface"
├── erc-4626
│   ├── ERC4626DepositOnly - "Minimal Deposit Only ERC4626 tokenized Vault implementation"
│   ├── ERC4626 - " Minimal ERC4626 tokenized Vault implementation"
│   └── interfaces
│       ├── IERC4626DepositOnly - "ERC4626DepositOnly Interface"
│       └── IERC4626 - "ERC4626 Interface"
├── gauges
│   ├── BaseV2Gauge - "Base contract for handling liquidity provider incentives"
│   ├── factories
│   │   ├── BaseV2GaugeFactory - "Handles the creation of new gauges and the management of existing ones"
│   │   ├── BaseV2GaugeManager - "Handles the management of gauges and gauge factories"
│   │   ├── BribesFactory - "Responsible for creating new bribe flywheel instances"
│   │   └── UniswapV3GaugeFactory - "Handles the creation of new Uniswap V3 gauges and the management of existing ones"
│   ├── interfaces
│   │   ├── IBaseV2GaugeFactory - "BaveV2GaugeFactory Interface"
│   │   ├── IBaseV2GaugeManager - "BaseV2GaugeManager Interface"
│   │   ├── IBaseV2Gauge - "BaseV2Gauge Interface"
│   │   ├── IBribesFactory - "BribesFactory Interface"
│   │   ├── IUniswapV3GaugeFactory - "UniswapV3GaugeFactory Interface"
│   │   └── IUniswapV3Gauge - "UniswapV3Gauge Interface"
│   └── UniswapV3Gauge - "Handles liquidity provider incentives for Uniswap V3 in the Base V2 Gauge implementation"
├── hermes
│   ├── BurntHermes - "BurntHermes: Yield bearing, boosting, voting, and gauge enabled Hermes"
│   ├── interfaces
│   │   ├── IBaseV2Minter - "BaseV2Minter Interface"
│   │   ├── IbHermesUnderlying - "bHermesUnderlying Interface"
│   │   └── IUtilityManager - "UtilityManager Interface"
│   ├── minters
│   │   └── BaseV2Minter - "Responsible for minting new tokens as per b(3,3) rules"
│   ├── tokens
│   │   ├── bHermesBoost - "bHermesBoost: Earns rights to boosted Hermes yield"
│   │   ├── bHermesGauges - "bHermesGauges: Directs Hermes emissions and receives fees/bribes"
│   │   ├── bHermesVotes - "bHermesVotes: Have power over Hermes' governance"
│   │   └── HERMES - "Hermes ERC20 token - Native token for the Hermes Incentive System"
│   └── UtilityManager - "Utility Tokens Manager Contract"
├── rewards
│   ├── base
│   │   ├── BaseFlywheelRewards - "Rewards Module for Flywheel"
│   │   └── FlywheelCore - "Flywheel Core Incentives Manager"
│   ├── booster
│   │   └── FlywheelBoosterGaugeWeight - "Balance Booster Module for Flywheel"
│   ├── depots
│   │   ├── MultiRewardsDepot - "Contract for multiple reward token storage"
│   │   ├── RewardsDepot - "Base contract for reward token storage"
│   │   └── SingleRewardsDepot - "Contract for a single reward token storage"
│   ├── FlywheelCoreInstant - "Manages instant incentives distribution under the Flywheel Core system"
│   ├── FlywheelCoreStrategy - "Manages per strategy incentives distribution under the Flywheel Core system"
│   ├── interfaces
│   │   ├── IFlywheelAcummulatedRewards - "FlywheelAcummulatedRewards Interface"
│   │   ├── IFlywheelBooster - "FlywheelBooster Interface"
│   │   ├── IFlywheelBribeRewards - "FlywheelBribeRewards Interface"
│   │   ├── IFlywheelCore - "FlywheelCore Interface"
│   │   ├── IFlywheelGaugeRewards - "FlywheelGaugeRewards Interface"
│   │   ├── IFlywheelInstantRewards - "FlywheelInstantRewards Interface"
│   │   ├── IFlywheelRewards - "FlywheelRewards Interface"
│   │   ├── IMultiRewardsDepot - "MultiRewardsDepot Interface"
│   │   └── IRewardsDepot - "RewardsDepot Interface"
│   └── rewards
│       ├── FlywheelAcummulatedRewards - "Accrues rewards for the Flywheel weekly"
│       ├── FlywheelBribeRewards - "Accrues bribes allocation to voters at the end of each epoch in accordance to votes"
│       ├── FlywheelGaugeRewards - "Distributes rewards from a stream based on gauge weights"
│       └── FlywheelInstantRewards - "This contract is responsible for strategy instant rewards management"
└── uni-v3-staker
    ├── interfaces
    │   └── IUniswapV3Staker - "UniswapV3Staker Interface"
    ├── libraries
    │   ├── IncentiveId - "Computes the UniswapV3Staker incentive identifier"
    │   ├── IncentiveTime - "Computes the UniswapV3Staker incentive start and end times"
    │   ├── NFTPositionInfo - "Encapsulates the logic for getting info about a NFT token ID"
    │   └── RewardMath - "Math for computing rewards for Uniswap V3 LPs with boost"
    └── UniswapV3Staker - "Uniswap V3 Staker with BurntHermes Boost"
test
├── erc-20
│   ├── ERC20BoostTest.t.sol
│   ├── ERC20GaugesTest.t.sol
│   ├── ERC20MultiVotes.t.sol
│   └── mocks
│       ├── MockERC20Boost.t.sol
│       ├── MockERC20Gauges.t.sol
│       └── MockERC20MultiVotes.t.sol
├── erc-4626
│   ├── ERC4626DepositOnlyTest.t.sol
│   ├── ERC4626Test.t.sol
│   └── mocks
│       ├── MockERC4626DepositOnly.t.sol
│       └── MockERC4626.t.sol
├── gauges
│   ├── BaseV2GaugeTest.t.sol
│   ├── factories
│   │   ├── BaseV2GaugeFactoryTest.t.sol
│   │   ├── BaseV2GaugeManagerTest.t.sol
│   │   ├── BribesFactoryTest.t.sol
│   │   └── UniswapV3GaugeFactoryTest.t.sol
│   ├── mocks
│   │   ├── MockBaseV2GaugeFactory.sol
│   │   ├── MockBaseV2GaugeManager.sol
│   │   ├── MockBaseV2Gauge.sol
│   │   └── MockERC20.sol
│   └── UniswapV3GaugeTest.t.sol
├── hermes
│   ├── BurntHermesTest.t.sol
│   ├── MinterTest.t.sol
│   ├── mocks
│   │   └── MockUtilityManager.t.sol
│   └── UtilityManagerTest.t.sol
├── mocks
│   ├── MockBooster.sol
│   └── MockRewardsStream.sol
├── rewards
│   ├── booster
│   │   └── FlywheelBoosterGaugeWeightTest.t.sol
│   ├── depots
│   │   └── MultiRewardsDepotTest.t.sol
│   ├── FlywheelInstantTest.t.sol
│   ├── FlywheelStrategyTest.t.sol
│   ├── mocks
│   │   ├── MockBooster.sol
│   │   ├── MockRewardsInstant.t.sol
│   │   ├── MockRewardsStrategy.t.sol
│   │   ├── MockRewardsStream.sol
│   │   └── MockSetBooster.sol
│   └── rewards
│       ├── FlywheelBribeRewardsTest.t.sol
│       ├── FlywheelGaugeRewardsTest.t.sol
│       └── FlywheelInstantRewardsTest.t.sol
├── uni-v3-staker
│   ├── IncentiveTimeTest.t.sol
│   ├── RewardMathTest.t.sol
│   └── UniswapV3StakerTest.t.sol
└── utils
    ├── invariant
    │   ├── handlers
    │   │   └── FlywheelBoosterGaugeWeightHandler.t.sol
    │   └── helpers
    │       └── AddressSet.sol
    ├── libraries
    │   ├── PoolActions.sol
    │   └── PoolVariables.sol
    └── UniswapV3Assistant.t.sol
```

## Local deployment and Usage

To utilize the contracts and deploy to a local testnet, you can install the code in your repo with forge:

```markdown
forge install https://github.com/Maia-DAO/hermes-v2
```

## License

[MIT](LICENSE) Copyright <YEAR> <COPYRIGHT HOLDER>

<!-- 
Update the following badge links for your repository:
- Replace 'Maia-DAO/foundry-template' with your repository path.
- Replace Maia DAO Discord link with your Discord server invite link.
-->

[version-badge]: https://img.shields.io/github/v/release/Maia-DAO/foundry-template
[version-link]: https://github.com/Maia-DAO/foundry-template/releases
[ci-badge]: https://github.com/Maia-DAO/foundry-template/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/Maia-DAO/foundry-template/actions/workflows/test.yml
[lint-badge]: https://github.com/Maia-DAO/foundry-template/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/Maia-DAO/foundry-template/actions/workflows/lint.yml
[coverage-badge]: .github/coverage-badge.svg
[coverage-link]: .github/coverage-badge.svg
[solidity-shield]: https://img.shields.io/badge/solidity-%5E0.8.0-aa6746
[license-badge]: https://img.shields.io/github/license/Maia-DAO/foundry-template
[license-link]: https://github.com/Maia-DAO/foundry-template/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/Ecosystem-documentation-informational
[docs-link]: https://v2-docs.maiadao.io/
[discussions-badge]: https://img.shields.io/badge/foundry-template-discussions-blueviolet
[discussions-link]: https://github.com/Maia-DAO/foundry-template/discussions
[js-library-badge]: https://img.shields.io/badge/foundry-template.js-library-red
[js-library-link]: https://github.com/Maia-DAO/foundry-template-js
[discord-badge]: https://img.shields.io/static/v1?logo=discord&label=discord&message=Join&color=blue
[discord-link]: https://discord.gg/maiadao
