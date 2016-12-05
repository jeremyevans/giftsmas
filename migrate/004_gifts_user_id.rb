require 'sequel_postgresql_triggers'

Sequel.migration do
  up do
    alter_table(:gifts) do
      add_foreign_key :user_id, :users
    end
    from(:gifts).update(:user_id=>from(:events).select(:user_id).where(:id=>Sequel[:gifts][:event_id]))
    alter_table(:gifts) do
      set_column_not_null :user_id
    end
    add_index :gifts, :user_id
    pgt_immutable(:gifts, :user_id, :function_name=>:immutable_user_id)

    create_function(:check_event_user, <<-SQL, :returns=>:trigger, :language=>:plpgsql)
    DECLARE
        check_user_id INTEGER;
    BEGIN
        SELECT user_id INTO STRICT check_user_id FROM events WHERE id = NEW.event_id;
        IF check_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'User IDs do not match: Gift: %, Event: %', NEW.user_id, check_user_id;
        END IF;
        RETURN NEW;
    END;
    SQL

    create_function(:check_gift_person, <<-SQL, :returns=>:trigger, :language=>:plpgsql, :replace=>true)
    DECLARE
        check_gift_user_id INTEGER;
        check_person_user_id INTEGER;
    BEGIN
        SELECT user_id INTO STRICT check_gift_user_id FROM gifts WHERE gifts.id = NEW.gift_id;
        SELECT user_id INTO STRICT check_person_user_id FROM people WHERE id = NEW.person_id;
        IF check_gift_user_id != check_person_user_id THEN
            RAISE EXCEPTION 'User IDs do not match: Gift: %, Person: %', check_gift_user_id, check_person_user_id;
        END IF;
        RETURN NEW;
    END;
    SQL

    create_trigger(:gifts, :check_event_user, :check_event_user, :events=>[:insert], :each_row=>true)
  end
  down do
    drop_trigger(:gifts, :check_event_user)
    drop_function(:check_event_user)

    alter_table(:gifts) do
      drop_column :user_id
    end
  end
end
