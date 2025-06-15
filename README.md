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
aztec-sandbox
```

Run the tests

```bash
yarn start
```
