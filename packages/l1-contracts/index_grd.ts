// This test should only use packages that are published to npm
// docs:start:imports
import { getInitialTestAccountsWallets } from '@aztec/accounts/testing';
import {
  EthAddress,
  Fr,
  createLogger,
  createPXEClient,
  waitForPXE,
} from '@aztec/aztec.js';
import { createExtendedL1Client, deployL1Contract } from '@aztec/ethereum';
import { GuardianBlockingContract } from './typings/GuardianBlocking.js';
import { describe, it } from 'node:test';

// docs:end:imports
// docs:start:utils
const MNEMONIC = 'test test test test test test test test test test test junk';
const { ETHEREUM_HOSTS = 'http://localhost:8545' } = process.env;

const l1Client = createExtendedL1Client(ETHEREUM_HOSTS.split(','), MNEMONIC);
const ownerEthAddress = l1Client.account.address;

const setupSandbox = async () => {
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  // eslint-disable-next-line @typescript-eslint/await-thenable
  const pxe = await createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

// docs:end:utils

describe('e2e_guardian_blocking_test', () => {
  it('Deploys GuardianBlocking contract and demonstrates guardian functionality', async () => {
    // docs:start:setup
    const logger = createLogger('aztec:guardian-blocking-tutorial');
    const pxe = await setupSandbox();
    const wallets = await getInitialTestAccountsWallets(pxe);
    const ownerWallet = wallets[0];
    const ownerAztecAddress = wallets[0].getAddress();
    const guardianWallet = wallets[1];
    const guardianAztecAddress = wallets[1].getAddress();
    const userWallet = wallets[2];
    const userAztecAddress = wallets[2].getAddress();
    const l1ContractAddresses = (await pxe.getNodeInfo()).l1ContractAddresses;
    logger.info('L1 Contract Addresses:');
    logger.info(`Registry Address: ${l1ContractAddresses.registryAddress}`);
    logger.info(`Inbox Address: ${l1ContractAddresses.inboxAddress}`);
    logger.info(`Outbox Address: ${l1ContractAddresses.outboxAddress}`);
    logger.info(`Rollup Address: ${l1ContractAddresses.rollupAddress}`);
    // docs:end:setup

    // Deploy GuardianBlocking contract
    // docs:start:deploy-guardian-blocking
    const guardianBlockingContract = await GuardianBlockingContract.deploy(
      ownerWallet,
      EthAddress.ZERO // Using zero address as portal since we're not using L1 functionality
    )
      .send()
      .deployed();
    logger.info(`GuardianBlocking contract deployed at ${guardianBlockingContract.address}`);
    // docs:end:deploy-guardian-blocking

    // Add guardian
    // docs:start:add-guardian
    await guardianBlockingContract.methods.add_guardian(guardianAztecAddress).send().wait();
    logger.info(`Added ${guardianAztecAddress} as a guardian`);
    // docs:end:add-guardian

    // Initiate blocking for a user
    // docs:start:initiate-blocking
    const guardianContract = await GuardianBlockingContract.at(guardianBlockingContract.address, guardianWallet);
    await guardianContract.methods.initiate_blocking(userAztecAddress).send().wait();
    logger.info(`Blocking initiated for user ${userAztecAddress}`);
    // docs:end:initiate-blocking

    // Approve blocking
    // docs:start:approve-blocking
    await guardianContract.methods.approve_blocking(userAztecAddress).send().wait();
    logger.info(`Blocking approved for user ${userAztecAddress}`);
    // docs:end:approve-blocking

    // Check if user is blocked
    // docs:start:check-blocked
    const isBlocked = await guardianBlockingContract.methods.is_user_blocked(userAztecAddress).simulate();
    logger.info(`Is user ${userAztecAddress} blocked? ${isBlocked}`);
    // docs:end:check-blocked

    // Remove guardian
    // docs:start:remove-guardian
    await guardianBlockingContract.methods.remove_guardian(guardianAztecAddress).send().wait();
    logger.info(`Removed ${guardianAztecAddress} as a guardian`);
    // docs:end:remove-guardian
  });
}); 