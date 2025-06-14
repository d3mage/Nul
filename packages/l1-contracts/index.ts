// This test should only use packages that are published to npm
// docs:start:imports
import { getInitialTestAccountsWallets } from '@aztec/accounts/testing';
import {
  EthAddress,
  Fr,
  L1TokenManager,
  L1TokenPortalManager,
  createLogger,
  createPXEClient,
  waitForPXE,
} from '@aztec/aztec.js';
import { createExtendedL1Client, deployL1Contract } from '@aztec/ethereum';
import {
  FeeAssetHandlerAbi,
  FeeAssetHandlerBytecode,
  TestERC20Abi,
  TestERC20Bytecode,
  TokenPortalAbi,
  TokenPortalBytecode,
} from '@aztec/l1-artifacts';
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import { TokenBridgeContract } from '@aztec/noir-contracts.js/TokenBridge';
import { NulWalletContract } from './typings/NulWallet.js';
import { describe, it } from 'node:test';

import { getContract, WalletClient } from 'viem';

// docs:end:imports
// docs:start:utils
const MNEMONIC = 'test test test test test test test test test test test junk';
const { ETHEREUM_HOSTS = 'http://localhost:8545' } = process.env;

const l1Client = createExtendedL1Client(ETHEREUM_HOSTS.split(','), MNEMONIC);
const ownerEthAddress = l1Client.account.address;

const MINT_AMOUNT = BigInt(1e15);

const setupSandbox = async () => {
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  // eslint-disable-next-line @typescript-eslint/await-thenable
  const pxe = await createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

async function deployTestERC20(): Promise<EthAddress> {
  const constructorArgs = ['Test Token', 'TEST', l1Client.account.address];

  return await deployL1Contract(l1Client, TestERC20Abi, TestERC20Bytecode, constructorArgs).then(
    ({ address }) => address,
  );
}

async function deployFeeAssetHandler(l1TokenContract: EthAddress): Promise<EthAddress> {
  const constructorArgs = [l1Client.account.address, l1TokenContract.toString(), MINT_AMOUNT];
  return await deployL1Contract(l1Client, FeeAssetHandlerAbi, FeeAssetHandlerBytecode, constructorArgs).then(
    ({ address }) => address,
  );
}

async function deployTokenPortal(): Promise<EthAddress> {
  return await deployL1Contract(l1Client, TokenPortalAbi, TokenPortalBytecode, []).then(({ address }) => address);
}

async function addMinter(l1TokenContract: EthAddress, l1TokenHandler: EthAddress) {
  const contract = getContract({
    address: l1TokenContract.toString(),
    abi: TestERC20Abi,
    client: l1Client as unknown as WalletClient,
  });
  await l1Client.writeContract({
    address: l1TokenContract.toString(),
    abi: TestERC20Abi,
    functionName: 'addMinter',
    args: [l1TokenHandler.toString()],
    account: l1Client.account.address,
  });
}
// docs:end:utils

describe('e2e_nul_wallet_test', () => {
  it('Deploys NulWallet and demonstrates voting functionality', async () => {
    // docs:start:setup
    const logger = createLogger('aztec:nul-wallet-tutorial');
    const pxe = await setupSandbox();
    const wallets = await getInitialTestAccountsWallets(pxe);
    const ownerWallet = wallets[0];
    const ownerAztecAddress = wallets[0].getAddress();
    const candidateWallet = wallets[1];
    const candidateAztecAddress = wallets[1].getAddress();
    const voterWallet = wallets[2];
    const voterAztecAddress = wallets[2].getAddress();
    const l1ContractAddresses = (await pxe.getNodeInfo()).l1ContractAddresses;
    logger.info('L1 Contract Addresses:');
    logger.info(`Registry Address: ${l1ContractAddresses.registryAddress}`);
    logger.info(`Inbox Address: ${l1ContractAddresses.inboxAddress}`);
    logger.info(`Outbox Address: ${l1ContractAddresses.outboxAddress}`);
    logger.info(`Rollup Address: ${l1ContractAddresses.rollupAddress}`);
    // docs:end:setup

    // Deploy NulWallet contract
    // docs:start:deploy-nul-wallet
    const nulWalletContract = await NulWalletContract.deploy(
      ownerWallet,
      ownerAztecAddress,
      EthAddress.ZERO // Using zero address as portal since we're not using L1 functionality
    )
      .send()
      .deployed();
    logger.info(`NulWallet contract deployed at ${nulWalletContract.address}`);
    // docs:end:deploy-nul-wallet

    // Add owner and voter as contacts
    // docs:start:add-contact
    await nulWalletContract.methods.add_contact(ownerAztecAddress).send().wait();
    logger.info(`Added ${ownerAztecAddress} as a contact`);
    
    await nulWalletContract.methods.add_contact(voterAztecAddress).send().wait();
    logger.info(`Added ${voterAztecAddress} as a contact`);
    // docs:end:add-contact

    // Cast vote using voter's wallet
    // docs:start:cast-vote
    const voterNulWallet = await NulWalletContract.at(nulWalletContract.address, voterWallet);
    await voterNulWallet.methods.cast_vote(candidateAztecAddress).send().wait();
    logger.info(`Vote cast for candidate ${candidateAztecAddress}`);
    // docs:end:cast-vote

    // Get vote count
    // docs:start:get-vote-count
    const voteCount = await nulWalletContract.methods.get_vote_count(candidateAztecAddress).simulate();
    logger.info(`Vote count for ${candidateAztecAddress}: ${voteCount}`);
    // docs:end:get-vote-count

    // Verify contact status
    // docs:start:verify-contact
    const isContact = await nulWalletContract.methods.is_address_in_contacts(voterAztecAddress).simulate();
    logger.info(`Is ${voterAztecAddress} a contact? ${isContact}`);
    // docs:end:verify-contact
  });
});