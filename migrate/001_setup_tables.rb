require 'sequel_postgresql_triggers'

class SetupTables < Sequel::Migration
  def up
    create_table :users do
      primary_key :id
      text :name, :null=>false
      char :salt, :null=>false, :size=>40
      char :password, :null=>false, :size=>40
      index :name, :unique=>true
      check :char_length[:name] > 0
    end

    create_table :events do
      primary_key :id
      text :name, :null=>false
      integer :num_gifts, :null=>false, :default=>0
      foreign_key :user_id, :users, :null=>false
      index [:name, :user_id], :unique=>true
      check :char_length[:name] > 0
    end

    create_table :people do
      primary_key :id
      text :name, :null=>false
      foreign_key :user_id, :users, :null=>false
      index [:name, :user_id], :unique=>true
      check :char_length[:name] > 0
    end

    create_table :gifts do
      primary_key :id
      text :name, :null=>false
      timestamp :inserted_at
      foreign_key :event_id, :events, :null=>false
      check :char_length[:name] > 0
    end

    create_table :gift_senders do
      foreign_key :gift_id, :gifts, :null=>false
      foreign_key :person_id, :people, :null=>false
      index [:gift_id, :person_id], :unique=>true
    end

    create_table :gift_receivers do
      foreign_key :gift_id, :gifts, :null=>false
      foreign_key :person_id, :people, :null=>false
      index [:gift_id, :person_id], :unique=>true
    end

    create_table :event_senders do
      foreign_key :event_id, :events, :null=>false
      foreign_key :person_id, :people, :null=>false
      index [:event_id, :person_id], :unique=>true
    end
    
    create_table :event_receivers do
      foreign_key :event_id, :events, :null=>false
      foreign_key :person_id, :people, :null=>false
      index [:event_id, :person_id], :unique=>true
    end
    
    create_language(:plpgsql)
    create_function(:check_event_person, <<-SQL, :returns=>:trigger, :language=>:plpgsql)
    DECLARE
        check_event_user_id INTEGER;
        check_person_user_id INTEGER;
    BEGIN
        SELECT user_id INTO STRICT check_event_user_id FROM events WHERE id = NEW.event_id;
        SELECT user_id INTO STRICT check_person_user_id FROM people WHERE id = NEW.person_id;
        IF check_event_user_id != check_person_user_id THEN
            RAISE EXCEPTION 'User IDs do not match: Event: %, Person: %', check_event_user_id, check_person_user_id;
        END IF;
        RETURN NEW;
    END;
    SQL

    create_function(:check_gift_person, <<-SQL, :returns=>:trigger, :language=>:plpgsql)
    DECLARE
        check_gift_user_id INTEGER;
        check_person_user_id INTEGER;
    BEGIN
        SELECT user_id INTO STRICT check_gift_user_id FROM events JOIN gifts ON (gifts.id = NEW.gift_id AND gifts.event_id = events.id);
        SELECT user_id INTO STRICT check_person_user_id FROM people WHERE id = NEW.person_id;
        IF check_gift_user_id != check_person_user_id THEN
            RAISE EXCEPTION 'User IDs do not match: Gift: %, Person: %', check_gift_user_id, check_person_user_id;
        END IF;
        RETURN NEW;
    END;
    SQL

    create_trigger(:gift_senders, :check_gift_sender, :check_gift_person, :events=>[:insert, :update], :each_row=>true)
    create_trigger(:gift_receivers, :check_gift_receiver, :check_gift_person, :events=>[:insert, :update], :each_row=>true)
    create_trigger(:event_senders, :check_event_sender, :check_event_person, :events=>[:insert, :update], :each_row=>true)
    create_trigger(:event_receivers, :check_event_receiver, :check_event_person, :events=>[:insert, :update], :each_row=>true)

    pgt_immutable(:events, :user_id, :function_name=>:immutable_user_id)
    pgt_immutable(:people, :user_id, :function_name=>:immutable_user_id)
    pgt_immutable(:gifts, :events_id, :function_name=>:immutable_event_id)
    pgt_counter_cache(:events, :id, :num_gifts, :gifts, :event_id, :function_name=>:cc_event_num_gifts)
    pgt_created_at(:gifts, :inserted_at, :function_name=>:inserted_at)
  end

  def down
    drop_table :gift_senders, :gift_receivers, :event_senders, :event_receivers, :gifts, :events, :people, :users 
    drop_function(:check_event_person)
    drop_function(:check_gift_person)
    drop_function(:immutable_user_id)
    drop_function(:immutable_event_id)
    drop_function(:cc_event_num_gifts)
    drop_function(:inserted_at)
    drop_language(:plpgsql)
  end
end
