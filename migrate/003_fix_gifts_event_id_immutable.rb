require 'sequel_postgresql_triggers'

Sequel.migration do
  up do
    pgt_immutable(:gifts, :event_id, :function_name=>:immutable_event_id)
  end
end
