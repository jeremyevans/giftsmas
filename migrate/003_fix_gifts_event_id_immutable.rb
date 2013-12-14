require 'sequel_postgresql_triggers'

class SetupTables < Sequel::Migration
  def up
    pgt_immutable(:gifts, :event_id, :function_name=>:immutable_event_id)
  end

  def down
  end
end
