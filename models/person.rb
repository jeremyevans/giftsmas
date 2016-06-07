module Giftsmas
class Person < Sequel::Model(DB)
  many_to_many :sender_events, :class=>"Giftsmas::Event", :join_table=>:event_senders, :right_key=>:event_id, :order=>:name
  many_to_many :receiver_events, :class=>"Giftsmas::Event", :join_table=>:event_receivers, :right_key=>:event_id, :order=>:name
  many_to_many :gifts_sent, :class=>"Giftsmas::Gift", :join_table=>:gift_senders, :right_key=>:gift_id, :order=>:inserted_at
  many_to_many :gifts_received, :class=>"Giftsmas::Gift", :join_table=>:gift_receivers, :right_key=>:gift_id, :order=>:inserted_at

  def self.for_user_by_id(user, id)
    first(:user_id=>user.id, :id=>id.to_i)
  end

  def self.for_user_by_name(user, name)
    find_or_create(:user_id=>user.id, :name=>name)
  end

  def make_receiver(e)
    add_receiver_event(e) unless receiver_events.include?(e)
    self
  end

  def make_sender(e)
    add_sender_event(e) unless sender_events.include?(e)
    self
  end
end
end

# Table: people
# Columns:
#  id      | integer | PRIMARY KEY DEFAULT nextval('people_id_seq'::regclass)
#  name    | text    | NOT NULL
#  user_id | integer | NOT NULL
# Indexes:
#  people_pkey               | PRIMARY KEY btree (id)
#  people_name_user_id_index | UNIQUE btree (name, user_id)
# Check constraints:
#  people_name_check | (char_length(name) > 0)
# Foreign key constraints:
#  people_user_id_fkey | (user_id) REFERENCES users(id)
# Referenced By:
#  event_receivers | event_receivers_person_id_fkey | (person_id) REFERENCES people(id)
#  event_senders   | event_senders_person_id_fkey   | (person_id) REFERENCES people(id)
#  gift_receivers  | gift_receivers_person_id_fkey  | (person_id) REFERENCES people(id)
#  gift_senders    | gift_senders_person_id_fkey    | (person_id) REFERENCES people(id)
# Triggers:
#  pgt_im_user_id | BEFORE UPDATE ON people FOR EACH ROW EXECUTE PROCEDURE immutable_user_id()
