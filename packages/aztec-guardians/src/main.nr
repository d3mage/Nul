mod config;

use dep::aztec::macros::aztec;

#[aztec]
pub contract GuardianBlocking {
    use crate::config::Config;
    use dep::value_note::value_note::ValueNote;
    use dep::aztec::{
        note::note_getter_options::NoteGetterOptions,
        note::note_interface::NoteProperties,
        note::note_viewer_options::NoteViewerOptions,
        utils::comparison::Comparator,
        macros::{functions::{initializer, internal, private, public, utility}, storage::storage},
        prelude::{AztecAddress, EthAddress, Map, PrivateSet, PublicMutable, PublicImmutable, PrivateMutable},
    };
    use dep::aztec::protocol_types::traits::ToField;

    #[storage]
    struct Storage<Context> {
        config: PublicImmutable<Config, Context>,
        // Map user -> Set of guardians
        user_guardians: Map<AztecAddress, PrivateSet<ValueNote, Context>, Context>,
        // Map user -> Map of guardian -> approval
        user_approvals: Map<AztecAddress, PrivateSet<ValueNote, Context>, Context>,
        // Map user -> blocking initiated status
        blocking_started: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        // Map user -> final blocked status
        user_blocked: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
    }

    // ========== Init ==========
    #[public]
    #[initializer]
    fn constructor(portal: EthAddress) {
        storage.config.initialize(Config { portal });
    }

    // ========== Guardian Management ==========

    #[private]
    fn add_guardian(guardian: AztecAddress) {
        let sender = context.msg_sender();
        let note = ValueNote::new(1, guardian);
        storage.user_guardians.at(sender).insert(note);
    }

    #[private]
    fn remove_guardian(guardian: AztecAddress) {
        let sender = context.msg_sender();
        let note = ValueNote::new(1, guardian);

        storage.user_guardians.at(sender).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, guardian)
            .set_limit(1));
    }

    // ========== Blocking Flow ==========

    #[private]
    fn initiate_blocking(user: AztecAddress) {
        let sender = context.msg_sender();
        let notes = storage.user_guardians.at(user).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, sender)
            .set_limit(1));
        assert(notes.len() == 1, "Not a guardian");

        let is_user_blocked = storage.user_blocked.at(user).get_note();
        assert(is_user_blocked.note.value == 1, "Already blocked");
        
        let is_blocking_started = storage.blocking_started.at(user).get_note();
        assert(is_blocking_started.note.value == 1, "Block already started");

        let note = ValueNote::new(1, user);
        storage.blocking_started.at(user).replace(note);

        let note = ValueNote::new(1, sender);
        storage.user_approvals.at(user).insert(note);
    }

    #[private]
    fn approve_blocking(user: AztecAddress) {
        let sender = context.msg_sender();

        let notes = storage.user_guardians.at(user).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, sender)
            .set_limit(1));
        assert(notes.len() == 1, "Not a guardian");

        let is_blocking_started = storage.blocking_started.at(user).get_note();
        assert(is_blocking_started.note.value == 1, "Blocking not started");

        let is_user_blocked = storage.user_blocked.at(user).get_note();
        assert(is_user_blocked.note.value == 1, "Already blocked");

        let note = ValueNote::new(1, sender);
        storage.user_approvals.at(user).insert(note);

        let mut all_approved = true;
        let all_notes = storage.user_guardians.at(user).get_notes(NoteGetterOptions::new());
        for i in 0..10 {
            if i < all_notes.len() {
              let note2 = all_notes.get_unchecked(i).note;
              storage.user_approvals.at(user);
              let user_approval_note = storage.user_approvals.at(user).pop_notes(NoteGetterOptions::new()
                .select(ValueNote::properties().owner, Comparator.EQ, sender)
                .set_limit(1));
              if user_approval_note.len() != 1 {
                  all_approved = false;
              }
            }
        }

        if all_approved {
            let new_user_blocked_note = ValueNote::new(1, user);
            storage.user_blocked.at(user).replace(new_user_blocked_note);
            context.message_portal(storage.config.read().portal, user.to_field());
        }
    }

    // ========== Utility ==========

    #[utility]
    unconstrained fn is_user_blocked(user: AztecAddress) -> bool {
      let is_user_blocked = storage.user_blocked.at(user).view_note();
      is_user_blocked.value == 1
    }
}
