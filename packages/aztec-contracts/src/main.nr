mod config;
mod vote_note;

use dep::aztec::macros::aztec;

#[aztec]
pub contract NulWallet {
    use crate::config::Config;

    use dep::aztec::prelude::{AztecAddress, EthAddress, PublicImmutable, PublicMutable, PrivateSet};
    use dep::aztec::macros::{functions::{initializer, private, public, view}, storage::storage};
    use dep::address_note::address_note::AddressNote;
    use dep::aztec::prelude::NoteGetterOptions;
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::note::note_interface::NoteProperties;
    use crate::vote_note::VoteNote;

    #[storage]
    struct Storage<Context> {
        config: PublicImmutable<Config, Context>,
        contacts: PrivateSet<AddressNote, Context>,
        votes: PrivateSet<VoteNote, Context>,
        vote_ended: PublicMutable<bool, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(owner: AztecAddress, portal: EthAddress) {
        storage.config.initialize(Config { owner, portal });
    }

    #[private]
    fn add_contact(address: AztecAddress) {

        let caller = context.msg_sender();
        let config = storage.config.read();
        assert(caller == config.owner, "Only the contract owner can add contacts");

        let note = AddressNote::new(
            address,
            caller
        );

        storage.contacts.insert(note);
    }

    #[private]
    fn is_address_in_contacts(address: AztecAddress) -> bool {
        //todo: notevieweroptions?
        let mut options = NoteGetterOptions::new();
        options.select(AddressNote::properties().address, Comparator.EQ, address);
        
        let notes = storage.contacts.get_notes(options);
        
        notes.len() > 0
    }

    #[private]
    fn cast_vote(candidate: AztecAddress) {
        let caller = context.msg_sender();
        //todo: check if this is a correct way to invoke a private function
        let is_contact = NulWallet::at(context.this_address()).is_address_in_contacts(caller).call(&mut context); 
        assert(is_contact, "Only contacts can vote");
        
        let config = storage.config.read();
        let vote_note = VoteNote::new(
            candidate,
            caller,
            config.owner
        );
        storage.votes.insert(vote_note);
    }

    #[private]
    fn get_vote_count(candidate: AztecAddress) -> u32 {
        //todo: notevieweroptions?
        let mut options = NoteGetterOptions::new();
        options.select(VoteNote::properties().candidate, Comparator.EQ, candidate);
        let votes = storage.votes.get_notes(options);
        votes.len() as u32
    }

}