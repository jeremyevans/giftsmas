require_relative 'spec_helper'
require_relative '../models'

db_name = Giftsmas::DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

include Giftsmas

describe Event do
  before(:all) do
    @user = User.create(:name=>'test', :password=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @sender = Person.create(:name=>'S', :user_id=>@user.id)
    @receiver = Person.create(:name=>'R', :user_id=>@user.id)
  end
  before do
    @user = User.call(@user.values.dup)
    @event = Event.call(@event.values.dup)
    @sender = Person.call(@sender.values.dup)
    @receiver= Person.call(@receiver.values.dup)
  end

  it "associations should be correct" do
    @event.user.class.must_equal User
    @event.gifts.must_equal []
    @event.senders.must_equal []
    @event.receivers.must_equal []
  end

  it ".compare_by_receiver should give a hash of rows and headers for gifts received in multiple events" do
    Event.compare_by_receiver.must_equal :rows=>[], :headers=>%w'Event Total Average'
    Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    Event.compare_by_receiver.must_equal :rows=>[['Christmas', 1, 1, 1]], :headers=>%w'Event R Total Average'
    Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    Event.compare_by_receiver.must_equal :rows=>[['Christmas', 2, 2, 2]], :headers=>%w'Event R Total Average'
    Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    Event.compare_by_receiver.must_equal :rows=>[['Christmas', 2, 1, 3, 1]], :headers=>%w'Event R S Total Average'
    event = Event.create(:name=>'Birthday', :user_id=>@user.id)
    Gift.add(event, 'G4', [@sender.id], [@receiver.id], [], [])
    Event.compare_by_receiver.must_equal :rows=>[['Birthday', 1, 0, 1, 1], ['Christmas', 2, 1, 3, 1]], :headers=>%w'Event R S Total Average'
  end

  it "#gifts_by_receiver should be a sorted hash of receivers and gifts received" do
    @event.gifts_by_receiver.must_equal []
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_receiver.must_equal [['R', [g]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_receiver.must_equal [['R', [g, g2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_by_receiver.must_equal [['R', [g, g2]], ['S', [g3]]]
  end

  it "#gifts_by_sender should be a sorted hash of senders and gifts sent" do
    @event.gifts_by_sender.must_equal []
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_sender.must_equal [['S', [g]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_sender.must_equal [['S', [g, g2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_by_sender.must_equal [['R', [g3]], ['S', [g, g2]]]
  end

  it "#gifts_crosstab should be an array of receiver names and array of rows of sender names and number of gifts for each receiver" do
    @event.gifts_crosstab.must_equal [[], []]
    Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_crosstab.must_equal [[:R], [['S', 1]]]
    Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_crosstab.must_equal [[:R], [['S', 2]]]
    Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_crosstab.must_equal [[:R, :S], [['R', 0, 1], ['S', 2, 0]]]
  end

  it "#gifts_summary should be two sorted hashes of senders and receivers with the number of gifts sent or received" do
    @event.gifts_summary.must_equal [[], []]
    Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_summary.must_equal [[['S', 1]], [['R', 1]]]
    Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_summary.must_equal [[['S', 2]], [['R', 2]]]
    Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_summary.must_equal [[['R', 1], ['S', 2]], [['R', 2], ['S', 1]]]
  end

  it "#thank_you_notes should be a sorted hash of receivers with values being a sorted hash of senders with an associated array of gifts, excluding gifts where the sender was a receiver in the event" do
    @event.thank_you_notes.must_equal []
    Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.thank_you_notes.must_equal [['R', [['S', ['G']]]]]
    Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.thank_you_notes.must_equal [['R', [['S', ['G', 'G2']]]]]
    Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.thank_you_notes.must_equal []
  end
end

describe Gift do
  before(:all) do
    @user = User.create(:name=>'test', :password_hash=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @sender = Person.create(:name=>'S', :user_id=>@user.id)
    @receiver = Person.create(:name=>'R', :user_id=>@user.id)
  end
  before do
    @user = User.call(@user.values.dup)
    @event = Event.call(@event.values.dup)
    @sender = Person.call(@sender.values.dup)
    @receiver= Person.call(@receiver.values.dup)
  end

  it "associations should be correct" do
    @gift = Gift.create(:name=>'G', :event_id=>@event.id)
    @gift.senders.must_equal []
    @gift.receivers.must_equal []
  end

  it ".add should add and return a gift with the given event, name, sender ids, receiver ids, sender names, and receiver names" do
    Gift.count.must_equal 0
    gift = Gift.add(@event, 'G', [@sender.id], [@receiver.id], ['S2'], ['R2'])
    Gift.count.must_equal 1
    gift.must_equal Gift.first
    gift.senders.map{|s| s.name}.must_equal %w'S S2'
    gift.receivers.map{|r| r.name}.must_equal %w'R R2'
  end

  it ".add should add new senders and receivers to the event, whether or not they already exist for the user" do
    Gift.count.must_equal 0
    gift = Gift.add(@event, 'G', [], [], %w'S S2', %w'R R2')
    @event.senders.map{|s| s.name}.must_equal %w'S S2'
    @event.receivers.map{|r| r.name}.must_equal %w'R R2'
    @event.gifts.must_equal [gift]
  end

  it ".add should return nil and not add a gift if it isn't given at least one sender and at least one receiver" do
    Gift.count.must_equal 0
    Gift.add(@event, 'G2', [], [], [], []).must_be_nil
    Gift.count.must_equal 0
    Gift.add(@event, 'G2', [@sender.id], [], ['S2'], []).must_be_nil
    Gift.count.must_equal 0
    Gift.add(@event, 'G2', [], [@receiver.id], [], ['R2']).must_be_nil
    Gift.count.must_equal 0
  end
end

describe Person do
  before(:all) do
    @user = User.create(:name=>'test', :password_hash=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @person = Person.create(:name=>'P', :user_id=>@user.id)
  end
  before do
    @user = User.call(@user.values.dup)
    @event = Event.call(@event.values.dup)
    @person = Person.call(@person.values.dup)
  end

  it "associations should be correct" do
    @person.sender_events.must_equal []
    @person.receiver_events.must_equal []
    @person.gifts_sent.must_equal []
    @person.gifts_received.must_equal []
  end

  it ".for_user_by_id should find a person with the given id for the given user" do
    Person.for_user_by_id(@user, @person.id).must_equal @person
  end
  
  it ".for_user_by_name should return the person for the given user with the given name if such person exists" do
    Person.for_user_by_name(@user, 'P').must_equal @person
    Person.count.must_equal 1
  end
  
  it ".for_user_by_name should create a new person with the given user and name if the user doesn't already have a person with that name" do
    person = Person.for_user_by_name(@user, 'P2')
    Person.count.must_equal 2
    person.wont_equal @person
    person.class.must_equal Person
  end
  
  it "#make_receiver should make this person a receiver in the given event" do
    @person.make_receiver(@event).must_equal @person
    @person.receiver_events.must_equal [@event]
    @person.make_receiver(@event).must_equal @person
    @person.reload.receiver_events.must_equal [@event]
  end
  
  it "#make_sender should make this person a sender in the given event" do
    @person.make_sender(@event).must_equal @person
    @person.sender_events.must_equal [@event]
    @person.make_sender(@event).must_equal @person
    @person.reload.sender_events.must_equal [@event]
  end
end

describe User do
  before(:all) do
    @user = User.create(:name=>'test', :password=>'blah')
  end
  before do
    @user = User.call(@user.values.dup)
  end

  it "associations should be correct" do
    @user.events.must_equal []
  end

  it "#password= should set a new password hash" do
    pw = @user.password_hash
    @user.password = 'foo'
    @user.password_hash.wont_equal pw
    @user.save
  end
end
