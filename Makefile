-include .env

.PHONY: all test clean deploy-anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy  "

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# install dependencies
install :; @forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install Cyfrin/foundry-devops --no-commit && forge install https://github.com/Uniswap/v2-core --no-commit && forge install https://github.com/Uniswap/v2-periphery --no-commit && forge install https://github.com/Uniswap/solidity-lib.git --no-commit

# update dependencies
update:; forge update

# compile
build:; forge build

# test
test :; forge test 
coverage:; @forge coverage --contracts FlamelingToken.sol
coverage-w:; @forge coverage --contracts FlamelingToken.sol --report debug > coverage.txt

# take snapshot
snapshot :; forge snapshot

# format
format :; forge fmt

# spin up local test network
anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# spin up fork
fork :; @anvil --fork-url ${RPC_BSC_MAIN} --fork-block-number 35267180 --fork-chain-id 56 --chain-id 123

# deployment
deploy-anvil :; @forge script script/DeployFlamelingToken.s.sol:DeployFlamelingToken --rpc-url http://localhost:8545  --private-key ${DEFAULT_ANVIL_KEY} --broadcast 
deploy-testnet :; @forge script script/DeployFlamelingToken.s.sol:DeployFlamelingToken --rpc-url ${RPC_BSC_MAIN}  --account ${TESTNET_ACCOUNT} --sender ${TESTNET_SENDER} --broadcast --verify --etherscan-api-key ${BSCSCAN_KEY}
deploy-mainnet :; @forge script script/DeployFlamelingToken.s.sol:DeployFlamelingToken --rpc-url ${RPC_BSC_MAIN}  --account ${MAINNET_ACCOUNT} --sender ${MAINNET_SENDER} --broadcast --verify --etherscan-api-key ${BSCSCAN_KEY}

# verifiying
verify :; @forge create --rpc-url ${network} --constructor-args ${args} --account ${account} --etherscan-api-key ${network} --verify src/FlamelingToken.sol:FlamelingToken

# security
slither :; slither ./src 

-include ${FCT_PLUGIN_PATH}/makefile-external