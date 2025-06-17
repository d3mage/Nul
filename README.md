# Token bridge tutorial

- Aztec sandbox, install with:

```bash
  bash -i <(curl -s install.aztec.network)
```

```bash
aztec-up
```

or

```bash
VERSION=0.87.4 aztec-up
```

### Compile

#### Aztec contracts

```bash
cd packages/aztec-contracts/token_bridge
aztec-nargo compile
aztec codegen target -o ../l1-contracts/typings/
```

#### L1 contracts

```bash
cd l1-contracts
yarn
npx hardhat compile
```

### Run

Run the sandbox

```bash
LOG_LEVEL="verbose" aztec start --sandbox
```

Reload the sandbox
```bash
# LOG_LEVEL=debug aztec start --sandbox todo: docker command
```

Run the tests

```bash
yarn start
```
```
aztec-wallet deploy \
    --node-url $NODE_URL \
    --from accounts:my-wallet \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --alias token \
    GuardianBlocking \
    --args accounts:my-wallet 0x572725ffb3af63745098576152d8756c333d4525 --no-wait
```