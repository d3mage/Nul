import { getInitialTestAccountsWallets } from '@aztec/accounts/testing';
import {
  EthAddress,
  createLogger,
  createPXEClient,
  waitForPXE,
} from '@aztec/aztec.js';
import { createExtendedL1Client } from '@aztec/ethereum';
import { NulWalletContract } from './typings/NulWallet.js';
import { describe, it } from 'node:test';


const MNEMONIC = 'test test test test test test test test test test test junk';
const { ETHEREUM_HOSTS = 'http://localhost:8545' } = process.env;

const l1Client = createExtendedL1Client(ETHEREUM_HOSTS.split(','), MNEMONIC);
const ownerEthAddress = l1Client.account.address;


const setupSandbox = async () => {
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  const pxe = await createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};


describe('e2e_nul_wallet_test', () => {
  it('Deploys NulWallet and demonstrates voting functionality', async () => {
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

    const nulWalletContract = await NulWalletContract.deploy(
      ownerWallet,
      ownerAztecAddress,
      EthAddress.ZERO
    )
      .send()
      .deployed();
    logger.info(`NulWallet contract deployed at ${nulWalletContract.address}`);

    await nulWalletContract.methods.add_contact(ownerAztecAddress).send().wait();
    logger.info(`Added ${ownerAztecAddress} as a contact`);

    let contactsLength = await nulWalletContract.methods.contacts_length().simulate();
    logger.info(`Contacts length: ${contactsLength}`);

    await nulWalletContract.methods.add_contact(voterAztecAddress).send().wait();
    logger.info(`Added ${voterAztecAddress} as a contact`);

    contactsLength = await nulWalletContract.methods.contacts_length().simulate();
    logger.info(`Contacts length: ${contactsLength}`);

    const allNotes = await pxe.getNotes({
      contractAddress: nulWalletContract.address,
      storageSlot: NulWalletContract.storage.contacts.slot,
      recipient: ownerAztecAddress,
    });

    console.log(`Found ${allNotes.length} contact notes.`);

    let is_address_in_contacts = await nulWalletContract.methods.is_address_in_contacts(ownerAztecAddress).simulate();
    logger.info(`Is address in contacts: ${is_address_in_contacts}`);

    is_address_in_contacts = await nulWalletContract.methods.is_address_in_contacts(voterAztecAddress).simulate();
    logger.info(`Is address in contacts: ${is_address_in_contacts}`);

    is_address_in_contacts = await nulWalletContract.methods.is_address_in_contacts(candidateAztecAddress).simulate();
    logger.info(`Is address in contacts: ${is_address_in_contacts}`);



    // const voterNulWallet = await NulWalletContract.at(nulWalletContract.address, voterWallet);
    // await voterNulWallet.methods.cast_vote(candidateAztecAddress).send().wait();
    // logger.info(`Vote cast for candidate ${candidateAztecAddress}`);

    // const voteCount = await nulWalletContract.methods.get_vote_count(candidateAztecAddress).simulate();
    // logger.info(`Vote count for ${candidateAztecAddress}: ${voteCount}`);

  });
});