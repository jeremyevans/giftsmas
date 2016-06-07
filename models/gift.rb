module Giftsmas
class Gift < Sequel::Model(DB)
  many_to_many :senders, :class=>"Giftsmas::Person", :join_table=>:gift_senders, :right_key=>:person_id, :order=>:name
  many_to_many :receivers, :class=>"Giftsmas::Person", :join_table=>:gift_receivers, :right_key=>:person_id, :order=>:name
  many_to_one :event

  def self.add(event, gift_name, senders, receivers, new_senders, new_receivers)
    return if gift_name.empty?
    user = event.user
    gift_senders = senders.map{|i| Person.for_user_by_id(user, i)}
    gift_receivers = receivers.map{|i| Person.for_user_by_id(user, i)}
    db.transaction do
      gift_senders += new_senders.map do |name|
        Person.for_user_by_name(user, name).make_sender(event)
      end
      gift_receivers += new_receivers.map do |name|
        Person.for_user_by_name(user, name).make_receiver(event)
      end
      gift_senders = gift_senders.compact.uniq
      gift_receivers = gift_receivers.compact.uniq
      if gift_senders.length > 0 and gift_receivers.length > 0
        gift = create(:user_id=>user.id, :event_id=>event.id, :name=>gift_name)
        gift_senders.each{|s| gift.add_sender(s)}
        gift_receivers.each{|s| gift.add_receiver(s)}
        gift
      end
    end
  end

  def self.recent(event, limit)
    where(:event_id=>event.id).
      reverse_order(:inserted_at, :id).
      limit(limit).
      eager(:senders, :receivers).
      all
  end

  def before_create
    self.user_id ||= event.user_id
    super
  end
end
end

# Table: gifts
# Columns:
#  id          | integer                     | PRIMARY KEY DEFAULT nextval('gifts_id_seq'::regclass)
#  name        | text                        | NOT NULL
#  inserted_at | timestamp without time zone |
#  event_id    | integer                     | NOT NULL
#  user_id     | integer                     | NOT NULL
# Indexes:
#  gifts_pkey          | PRIMARY KEY btree (id)
#  gifts_user_id_index | btree (user_id)
# Check constraints:
#  gifts_name_check | (char_length(name) > 0)
# Foreign key constraints:
#  gifts_event_id_fkey | (event_id) REFERENCES events(id)
#  gifts_user_id_fkey  | (user_id) REFERENCES users(id)
# Referenced By:
#  gift_receivers | gift_receivers_gift_id_fkey | (gift_id) REFERENCES gifts(id)
#  gift_senders   | gift_senders_gift_id_fkey   | (gift_id) REFERENCES gifts(id)
# Triggers:
#  check_event_user                       | BEFORE INSERT ON gifts FOR EACH ROW EXECUTE PROCEDURE check_event_user()
#  pgt_ca_inserted_at                     | BEFORE INSERT OR UPDATE ON gifts FOR EACH ROW EXECUTE PROCEDURE inserted_at()
#  pgt_cc_events__id__num_gifts__event_id | BEFORE INSERT OR DELETE ON gifts FOR EACH ROW EXECUTE PROCEDURE cc_event_num_gifts()
#  pgt_im_event_id                        | BEFORE UPDATE ON gifts FOR EACH ROW EXECUTE PROCEDURE immutable_event_id()
#  pgt_im_events_id                       | BEFORE UPDATE ON gifts FOR EACH ROW EXECUTE PROCEDURE immutable_event_id()
#  pgt_im_user_id                         | BEFORE UPDATE ON gifts FOR EACH ROW EXECUTE PROCEDURE immutable_user_id()
