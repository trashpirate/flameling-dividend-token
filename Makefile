-include .env

.PHONY: all test clean deploy-anvil

slither :; slither ./src 

install:; @forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install Cyfrin/foundry-devops --no-commit && forge install https://github.com/Uniswap/v2-core --no-commit && forge install https://github.com/Uniswap/v2-periphery --no-commit && forge install https://github.com/Uniswap/solidity-lib.git --no-commit

anvil :; anvil -m 'test test test test test test test test test test test junk'

anvil-fork :; @anvil --fork-url ${RPC_BSC} --fork-block-number 35267180 --fork-chain-id 56 --chain-id 123

# Localhost deployment
# use --legacy for BSC
deploy-local :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url localhost --account ${LOCAL_ACCOUNT} --sender ${LOCAL_SENDER} --broadcast --legacy -vv


# use the "@" to hide the command from your shell, use contract=<contract name>
deploy-testnet-sim :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${TESTNET_ACCOUNT} --sender ${TESTNET_SENDER} -vv
deploy-testnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${TESTNET_ACCOUNT} --sender ${TESTNET_SENDER} --broadcast --verify --etherscan-api-key ${network}
deploy-testnet-no-verify :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${TESTNET_ACCOUNT} --sender ${TESTNET_SENDER} --broadcast

deploy-mainnet-sim :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${MAINNET_ACCOUNT} --sender ${MAINNET_SENDER}
deploy-mainnet-no-verify :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${MAINNET_ACCOUNT} --sender ${MAINNET_SENDER} --broadcast
deploy-mainnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${MAINNET_ACCOUNT} --sender ${MAINNET_SENDER} --broadcast --verify --etherscan-api-key ${network}

# verifiying
verify :; @forge create --rpc-url ${network} --constructor-args ${args} --account ${account} --etherscan-api-key ${network} --verify src/${contract}.sol:${contract}
verify-base :; @forge verify-contract --chain-id 8453 --num-of-optimizations 200 --constructor-args ${args} --etherscan-api-key ${BASESCAN_KEY} ${contractAddress} src/${contract}.sol:${contract} --watch
verify-avax-test :; @forge verify-contract --chain-id 43113 --num-of-optimizations 200 --constructor-args $(args) --etherscan-api-key "verifyContract" ${contractAddress} src/${contract}.sol:${contract} --watch --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan'

abi-encode :; cast abi-encode "constructor(address)" ${args}

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 

deploy-all :; make deploy-${network} contract=APIConsumer && make deploy-${network} contract=KeepersCounter && make deploy-${network} contract=PriceFeedConsumer && make deploy-${network} contract=VRFConsumerV2

test-fork-unit :; @forge test --match-path test/unit/${contract}.t.sol --rpc-url localhost ${output}

test-fork-test :; @forge test --match-test ${test} --rpc-url localhost ${output}

test-fork-all :; @forge test --rpc-url localhost ${output}

# test-fork-fuzz :; @forge test --match-path test/fuzz/* --rpc-url localhost

# test-fork-unit :; @forge test --match-path test/unit/* --rpc-url localhost

# test-fork-integration :; @forge test --match-path test/integration --rpc-url localhost

bnb-balance :; @cast call ${BNB_ADDRESS} "balanceOf(address)(uint256)" ${account}

send-bnb :; @cast rpc anvil_impersonateAccount ${BNB_ACCOUNT} && cast send ${BNB_ADDRESS} --unlocked --from ${BNB_ACCOUNT} "transfer(address,uint256)(bool)" ${account} ${amount}

coverage :; @forge coverage --contracts FlamelingToken.sol --fork-url localhost

-include ${FCT_PLUGIN_PATH}/makefile-external