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
        prelude::{AztecAddress, EthAddress, Map, PrivateSet, SharedMutable, PublicImmutable, PrivateMutable},
    };
    use dep::aztec::protocol_types::traits::ToField;

    global CHANGE_AUTHORIZED_DELAY_BLOCKS: u32 = 5;

    #[storage]
    struct Storage<Context> {
        config: PublicImmutable<Config, Context>,
        // Map user -> Set of guardians
        user_guardians: Map<AztecAddress, PrivateSet<ValueNote, Context>, Context>,
        // Map user -> number of guardian approvals
        approval_count: Map<AztecAddress, SharedMutable<u32, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        // Map user -> total number of guardians
        guardian_count: Map<AztecAddress, SharedMutable<u32, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        // Map user -> blocking initiated status
        blocking_started: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        // Map user -> final blocked status (1 = blocked, 0 = not blocked)
        user_blocked: Map<AztecAddress, SharedMutable<u32, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
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
        
        // Schedule guardian count increment
        GuardianBlocking::at(context.this_address()).increment_guardian_count(sender).enqueue(
            &mut context
        );
    }

    #[public]
    #[internal]
    fn increment_guardian_count(user: AztecAddress) {
        let current_count = storage.guardian_count.at(user).get_current_value();
        storage.guardian_count.at(user).schedule_value_change(current_count + 1);
    }

    #[private]
    fn remove_guardian(guardian: AztecAddress) {
        let sender = context.msg_sender();

        let removed_notes = storage.user_guardians.at(sender).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, guardian)
            .set_limit(1));
            
        if removed_notes.len() == 1 {
            GuardianBlocking::at(context.this_address()).decrement_guardian_count(sender).enqueue(
                &mut context
            );
        }
    }

    #[public]
    #[internal]
    fn decrement_guardian_count(user: AztecAddress) {
        let current_count = storage.guardian_count.at(user).get_current_value();
        storage.guardian_count.at(user).schedule_value_change(current_count - 1);
    }

    // ========== Blocking Flow ==========

    #[private]
    fn initiate_blocking(user: AztecAddress) {
        let sender = context.msg_sender();
        let notes = storage.user_guardians.at(user).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, sender)
            .set_limit(1));
        assert(notes.len() == 1, "Not a guardian");

        let is_user_blocked = storage.user_blocked.at(user).get_current_value();
        assert(is_user_blocked == 0, "Already blocked");

        let note = ValueNote::new(1, user);
        storage.blocking_started.at(user).replace(note);

        // Initialize approval count
        GuardianBlocking::at(context.this_address()).set_public_block(user).enqueue(
            &mut context
        );
    }

    #[public]
    #[internal]
    fn set_public_block(user: AztecAddress) {
        storage.approval_count.at(user).schedule_value_change(1);
    }

    #[private]
    fn approve_blocking(user: AztecAddress) {
        let sender = context.msg_sender();

        let notes = storage.user_guardians.at(user).pop_notes(NoteGetterOptions::new()
            .select(ValueNote::properties().owner, Comparator.EQ, sender)
            .set_limit(1));
        assert(notes.len() == 1, "Not a guardian");

        let is_user_blocked = storage.user_blocked.at(user).get_current_value();
        assert(is_user_blocked == 0, "Already blocked");

        GuardianBlocking::at(context.this_address()).increment_approval_count(user).enqueue(
            &mut context
        );

        GuardianBlocking::at(context.this_address()).check_block_user(user).enqueue(
            &mut context
        );
    }

    #[public]
    #[internal]
    fn check_block_user(user: AztecAddress) {
        let total_guardians = storage.guardian_count.at(user).get_current_value();
        let scheduled_approvals = storage.approval_count.at(user).get_current_value();
        if scheduled_approvals == total_guardians {
            storage.user_blocked.at(user).schedule_value_change(1);
        }
    }

    #[public]
    #[internal]
    fn increment_approval_count(user: AztecAddress) {
        let current_approvals = storage.approval_count.at(user).get_current_value();
        storage.approval_count.at(user).schedule_value_change(current_approvals + 1);
    }

    // ========== Utility ==========

    #[utility]
    unconstrained fn is_user_blocked(user: AztecAddress) -> bool {
        storage.user_blocked.at(user).get_current_value() == 1
    }
}
