# FLAMELING TOKEN 🔥

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg?style=for-the-badge)
![Forge](https://img.shields.io/badge/Forge-v0.2.0-blue?style=for-the-badge)
[![License: MIT](https://img.shields.io/github/license/trashpirate/hold-earn.svg?style=for-the-badge)](https://github.com/trashpirate/hold-earn/blob/main/LICENSE)

[![Website: nadinaoates.com](https://img.shields.io/badge/Portfolio-00e0a7?style=for-the-badge&logo=Website)](https://nadinaoates.com)
[![LinkedIn: nadinaoates](https://img.shields.io/badge/LinkedIn-0a66c2?style=for-the-badge&logo=LinkedIn&logoColor=f5f5f5)](https://linkedin.com/in/nadinaoates)
[![Twitter: N0\_crypto](https://img.shields.io/badge/@N0\_crypto-black?style=for-the-badge&logo=X)](https://twitter.com/N0\_crypto)

<!-- ![Node](https://img.shields.io/badge/node-v20.10.0-blue.svg?style=for-the-badge)
![NPM](https://img.shields.io/badge/npm-v10.2.3-blue?style=for-the-badge)
![Nextjs](https://img.shields.io/badge/next-v13.5.4-blue?style=for-the-badge)
![Tailwindcss](https://img.shields.io/badge/TailwindCSS-v3.0-blue?style=for-the-badge)
![Wagmi](https://img.shields.io/badge/Wagmi-v1.4.3-blue?style=for-the-badge) -->

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#usage">Usage</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <!-- <li><a href="#acknowledgments">Acknowledgments</a></li> -->
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

Smart contract for an ERC20 Dividend Token contract called `FlamelingToken`. The token is supposed to be launched on BNB chain. The token has a 0% transaction fee but a 4% fee on buys and sells on Uniswap V2. Half of the fee (2%) is called a base fee which is swapped to BNB and sent to a "operations" wallet defined during deployment. The other half of the fee is swapped to the BEP-20 token $EARN which is then distributed to holders according to their percentage holding. To receive dividends, the holders need to hold at least 100,000 Flameling Tokens.

**Distrubtion of Fees**  
The fees of buys and sells on Uniswap V2 are accumulated in the contract until the `s_swapThreshold` is hit. Then half of the tokens in the contract are swapped to BNB and sent to the `s_baseFeeAddress`. The other half of the fees are swapped to the ERC20 `s_dividendToken` which is distributed as dividends to holders. Only holders that have at least `s_minSharesRequired` can receive dividends. Dividends are distributed during sell and regular transfer transactions looping through all the dividend accounts while the gas is limited to `s_gasForProcessing`. 

**Contract Structure**
The dividend logic including updating dividend accounts, distributing dividends, and processing dividend payout are in the `DividendShares.sol` contract. This contract inherits from `Ownable.sol` from the OpenZeppelin Library. The `FlamelingToken.sol` inherits from `DividendShares.sol` and implements the logic of the ERC20 FlamelingToken. `FlamelingToken.sol` inherits from `ERC20.sol` from OpenZeppelin Library and overrides the `_update(address from, address to, uint256 amount)` function to adjust for the fee collection, swapping, and dividend distribution.

### Smart Contracts on BSC Testnet

### Smart Contracts Mainnet

<!-- GETTING STARTED -->
## Getting Started

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/trashpirate/flameling-token.git
   ```
2. Navigate to the project directory
   ```sh
   cd flameling-token
   ```
3. Install Forge submodules
   ```sh
   forge install
   ```

### Usage

#### Compiling
```sh
forge compile
```

#### Testing locally

Run local tests:  
```sh
forge test
```

Run test with bsc mainnet fork:
1. Start local test environment
    ```sh
    make fork
    ```
2. Run fork tests
    ```sh
    forge test
    ```

#### Deployment

Create a .env file and add following information:
```
# network configs
RPC_LOCALHOST="http://127.0.0.1:8545"

# binance smart chain
RPC_BSC_TEST="<rpc-url-testnet>"
RPC_BSC_MAIN="rpc-url-mainnet"
BSCSCAN_KEY="<your-api-key>"

# wallet configs
# MAINNET_SENDER="0x"
MAINNET_SENDER="0x"
TESTNET_SENDER="0x"
LOCAL_SENDER="0x"

MAINNET_ACCOUNT="EARN-Deployer"
MAINNET_ACCOUNT="Test-BNBMain-Deployer"
TESTNET_ACCOUNT="Testnet-Deployer"
LOCAL_ACCOUNT="Local-Deployer"
```

##### Deploy to BSC testnet

1. Create test wallet using keystore. Enter private key of test wallet when prompted.
    ```sh
    cast wallet import Testnet-Deployer --interactive
    ```
    
2. Deploy to BSC testnet
    ```sh
    make deploy-testnet
    ```

##### Deploy to BSC mainnet
1. Create deployer wallet using keystore. Enter private key of deployer wallet when prompted.
    ```sh
    cast wallet import Test-BNBMain-Deployer --interactive
    ```
    
2. Deploy to BSC mainnet
    ```sh
    make deploy-mainnet
    ```

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<!-- CONTACT -->
## Contact

Nadina Oates - [@N0_crypto](https://twitter.com/N0_crypto)

Project Link: [https://flamestarters.buyholdearn.com](https://flamestarters.buyholdearn.com)


<!-- ACKNOWLEDGMENTS -->
<!-- ## Acknowledgments -->
