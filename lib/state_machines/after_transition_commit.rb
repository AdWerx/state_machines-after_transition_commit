require "state_machines"
require "state_machines-activerecord"
require "state_machines/after_transition_commit/version"

module StateMachines
  module AfterTransitionCommit
    # Blocks are registered on the transaction, so there is no model callback to
    # install. Kept so state machines that still call it keep loading.
    def add_after_transition_commit_callback; end

    # Registered on the transaction rather than the record: Active Record may run
    # a record's after_commit on a different in-memory copy of the same row.
    def after_transition_commit(*args, &after_transition_block)
      after_transition(*args) do |object, _transition|
        object.class.current_transaction.after_commit do
          after_transition_block.call(object)
        end
      end
    end
  end
end

StateMachines::Machine.include StateMachines::AfterTransitionCommit
