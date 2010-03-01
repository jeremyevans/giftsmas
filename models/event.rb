class Event < Sequel::Model
  @scaffold_fields = [:name]
  @scaffold_session_value = :user_id
  @scaffold_associations = [:gifts, :receivers, :senders]
  @scaffold_order = [:name]
  many_to_one :user
  one_to_many :gifts, :eager=>[:receivers, :senders], :order=>:inserted_at
  many_to_many :senders, :class=>:Person, :join_table=>:event_senders, :right_key=>:person_id, :order=>:name
  many_to_many :receivers, :class=>:Person, :join_table=>:event_receivers, :right_key=>:person_id, :order=>:name

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
      join(:gift_senders, :gift_id=>:gifts__id).
      join(:people.as(:sender), :id=>:person_id).
      select(:sender__name.as(:sender_name), *person_names.sort.map{|k,v| :sum[{k=>1}.case(0, :gift_receivers__person_id)].as(v)}).
      group_by(:sender__name).
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
      h.values.each{|h2| h2.sort}
      h.sort
    end
    receivers.sort.map{|k, v| [k, v.sort.map{|k2, v2| [k2, v2.sort]}]}
  end
end
