class Person < Sequel::Model
  @scaffold_fields = [:name]
  @scaffold_session_value = :user_id
  @scaffold_associations = [:sender_events, :receiver_events, :gifts_sent, :gifts_received]

  many_to_many :sender_events, :class=>:Event, :join_table=>:event_senders, :right_key=>:event_id, :order=>:name
  many_to_many :receiver_events, :class=>:Event, :join_table=>:event_receivers, :right_key=>:event_id, :order=>:name
  many_to_many :gifts_sent, :class=>:Gift, :join_table=>:gift_senders, :right_key=>:gift_id, :order=>:inserted_at
  many_to_many :gifts_received, :class=>:Gift, :join_table=>:gift_receivers, :right_key=>:gift_id, :order=>:inserted_at

  def self.for_user_by_id(user, id)
    first(:user_id=>user.id, :id=>id)
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
