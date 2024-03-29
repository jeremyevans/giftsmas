# frozen_string_literal: true
module Giftsmas
class Event < Model
  many_to_one :user
  one_to_many :gifts, :eager=>[:receivers, :senders], :order=>:id
  many_to_many :senders, :class=>"Giftsmas::Person", :join_table=>:event_senders, :right_key=>:person_id, :order=>:name
  many_to_many :receivers, :class=>"Giftsmas::Person", :join_table=>:event_receivers, :right_key=>:person_id, :order=>:name

  dataset_module do
    def compare_by_receiver
      ds = self
      events = ds.to_hash(:id, :name)
      gift_ds = Gift.where(:event_id=>ds.select(:id)).naked
      receiver_ds = DB[:gift_receivers].select(:person_id)
  
      person_ds = Person.where(:id=>receiver_ds.where(:gift_id=>gift_ds.select(:id))).
        order(:name)

      people = person_ds.to_hash(:id, :name)
      receivers = person_ds.select_map(:id)
  
      select_receivers = receivers.map do |id|
        Sequel.function(:sum, Sequel.case({{id=>receiver_ds.where(:gift_id=>Sequel[:gifts][:id])}=>1}, 0)).as(id.to_s)
      end
  
      gifts_by_receiver = gift_ds.
        group(:event_id).
        select_map([:event_id] + select_receivers).
        each do |r|
          r[0] = events[r[0]]
          r << r[1..-1].inject(:+)
          r << r[-1]/r[1..-2].reject{|x| x == 0}.length
        end.sort
      
      {:rows=>gifts_by_receiver, :headers=>['Event'] + receivers.map{|id| people[id]} + ['Total', 'Average']}
    end
  end

  def gifts_by_receiver
    receivers = Hash.new{|h,k| h[k] = []}
    gifts.each do |g|
      g.receivers.each{|s| receivers[s.name] << g}
    end
    receivers.sort
  end

  def gifts_by_sender
    senders = Hash.new{|h,k| h[k] = []}
    gifts.each do |g|
      g.senders.each{|s| senders[s.name] << g}
    end
    senders.sort
  end

  def gifts_crosstab
    person_ids = model.db[:gifts].join(:gift_receivers, :gift_id=>:id).filter(:event_id=>id).distinct.select_order_map(:person_id)
    person_names = model.db[:people].filter(:id=>person_ids).order(:name).map{|x| [x[:id], x[:name]]}
    person_name_values = person_names.map{|x| x.last.to_sym}
    rows = model.db[:gifts].
      filter(:event_id=>id).
      join(:gift_receivers, :gift_id=>:id).
      join(:gift_senders, :gift_id=>Sequel[:gifts][:id]).
      join(Sequel.as(:people, :sender), :id=>:person_id).
      select(Sequel.as(Sequel[:sender][:name], :sender_name), *person_names.sort.map{|k,v| Sequel.function(:sum, Sequel.case({k=>1}, 0, Sequel[:gift_receivers][:person_id])).as(v)}).
      group_by(Sequel[:sender][:name]).
      order(:sender_name).map{|r| [r[:sender_name]] + person_name_values.map{|x| r[x]}}
    [person_name_values, rows]
  end

  def gifts_summary
    senders = Hash.new(0)
    receivers = Hash.new(0)
    gifts.each do |g|
      g.senders.each{|s| senders[s.name] += 1}
      g.receivers.each{|s| receivers[s.name] += 1}
    end
    [senders.sort, receivers.sort]
  end

  def thank_you_notes
    receivers = Hash.new{|h,k| h[k] = Hash.new{|h2,k| h2[k] = []}}
    person_ids = model.db[:gifts].join(:gift_receivers, :gift_id=>:id).filter(:event_id=>id).select(:person_id).distinct(:person_id).order(:person_id).map(:person_id)
    gifts.each do |g|
      g.receivers.each do |r|
        g.senders.reject{|s| person_ids.include?(s.id)}.each{|s| receivers[r.name][s.name] << g.name}
      end
    end
    receivers.values.each do |h| 
      h.values.each(&:sort)
      h.sort
    end
    receivers.sort.map{|k, v| [k, v.sort.map{|k2, v2| [k2, v2.sort]}]}
  end
end
end

# Table: events
# Columns:
#  id        | integer | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  name      | text    | NOT NULL
#  num_gifts | integer | NOT NULL DEFAULT 0
#  user_id   | integer | NOT NULL
# Indexes:
#  events_pkey               | PRIMARY KEY btree (id)
#  events_name_user_id_index | UNIQUE btree (name, user_id)
# Check constraints:
#  events_name_check | (char_length(name) > 0)
# Foreign key constraints:
#  events_user_id_fkey | (user_id) REFERENCES users(id)
# Referenced By:
#  event_receivers | event_receivers_event_id_fkey | (event_id) REFERENCES events(id)
#  event_senders   | event_senders_event_id_fkey   | (event_id) REFERENCES events(id)
#  gifts           | gifts_event_id_fkey           | (event_id) REFERENCES events(id)
# Triggers:
#  pgt_im_user_id | BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION immutable_user_id()
