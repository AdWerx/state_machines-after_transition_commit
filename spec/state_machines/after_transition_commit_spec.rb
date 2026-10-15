require 'spec_helper'

RSpec.describe StateMachines::AfterTransitionCommit do
  it "has a version number" do
    expect(StateMachines::AfterTransitionCommit::VERSION).not_to be nil
  end

  subject { cat.poke! }
  let(:cat) { create(:cat) }

  it 'only executes callbacks after the record was committed' do
    block_was_run = false
    cat_name = cat.name

    block = lambda do |record|
      block_was_run = true
      cat_name = record.name
    end

    cat.class.after_commit(&block)

    expect do
      expect { cat.poke! }.not_to(change { cat_name })
    end.to change { cat.state.to_sym }.from(:asleep).to(:grumpy)

    expect(cat.name).to eq('Grumpy Cat')
  end

  describe 'blocks registered on the transaction' do
    before { Cat.committed_pets.clear }

    it 'waits for the outermost transaction to commit' do
      cat = create(:cat, state: :grumpy)
      pets_inside_transaction = nil

      Cat.transaction do
        cat.pet!
        pets_inside_transaction = Cat.committed_pets.dup
      end

      expect(pets_inside_transaction).to be_empty
      expect(Cat.committed_pets).to eq([cat])
    end

    it 'drops the block when the transaction rolls back' do
      cat = create(:cat, state: :grumpy)

      Cat.transaction do
        cat.pet!
        raise ActiveRecord::Rollback
      end
      cat.update!(name: 'Saved Later')

      expect(Cat.committed_pets).to be_empty
    end

    [true, false].each do |first_saved|
      context "when run_commit_callbacks_on_first_saved_instances_in_transaction is #{first_saved}" do
        around do |example|
          original = ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction
          ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction = first_saved
          example.run
        ensure
          ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction = original
        end

        it 'runs once on the transitioned copy when another copy of the row saves afterwards' do
          cat = create(:cat, state: :grumpy)
          other_copy = Cat.find(cat.id)

          Cat.transaction do
            cat.pet!
            other_copy.update!(name: 'Other Copy')
          end

          expect(Cat.committed_pets).to contain_exactly(be(cat))
        end
      end
    end
  end
end
