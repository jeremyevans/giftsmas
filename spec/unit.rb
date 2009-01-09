#!/usr/local/bin/spec
GIFTSMAS_ENV = :test
require 'models'

class Spec::Example::ExampleGroup
  def execute(*args, &block)
    DB.transaction{super(*args, &block); raise Sequel::Error::Rollback}
  end
end

describe Event do
  before do
    @user = User.create(:name=>'test', :salt=>'', :password=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @sender = Person.create(:name=>'S', :user_id=>@user.id)
    @receiver = Person.create(:name=>'R', :user_id=>@user.id)
  end

  specify "associations should be correct" do
    @event.user.class.should == User
    @event.gifts.should == []
    @event.senders.should == []
    @event.receivers.should == []
  end

  specify "#gifts_by_receiver should be a sorted hash of receivers and gifts received" do
    @event.gifts_by_receiver.should == []
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_receiver.should == [['R', [g]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_receiver.should == [['R', [g, g2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_by_receiver.should == [['R', [g, g2]], ['S', [g3]]]
  end

  specify "#gifts_by_sender should be a sorted hash of senders and gifts sent" do
    @event.gifts_by_sender.should == []
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_sender.should == [['S', [g]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_by_sender.should == [['S', [g, g2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_by_sender.should == [['R', [g3]], ['S', [g, g2]]]
  end

  specify "#gifts_crosstab should be an array of receiver names and array of rows of sender names and number of gifts for each receiver" do
    @event.gifts_crosstab.should == [[], []]
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_crosstab.should == [[:R], [['S', 1]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_crosstab.should == [[:R], [['S', 2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_crosstab.should == [[:R, :S], [['R', 0, 1], ['S', 2, 0]]]
  end

  specify "#gifts_summary should be two sorted hashes of senders and receivers with the number of gifts sent or received" do
    @event.gifts_summary.should == [[], []]
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_summary.should == [[['S', 1]], [['R', 1]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.gifts_summary.should == [[['S', 2]], [['R', 2]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.gifts_summary.should == [[['R', 1], ['S', 2]], [['R', 2], ['S', 1]]]
  end

  specify "#thank_you_notes should be a sorted hash of receivers with values being a sorted hash of senders with an associated array of gifts, excluding gifts where the sender was a receiver in the event" do
    @event.thank_you_notes.should == []
    g = Gift.add(@event, 'G', [@sender.id], [@receiver.id], [], [])
    @event.reload.thank_you_notes.should == [['R', [['S', ['G']]]]]
    g2 = Gift.add(@event, 'G2', [@sender.id], [@receiver.id], [], [])
    @event.reload.thank_you_notes.should == [['R', [['S', ['G', 'G2']]]]]
    g3 = Gift.add(@event, 'G3', [@receiver.id], [@sender.id], [], [])
    @event.reload.thank_you_notes.should == []
  end
end

describe Gift do
  before do
    @user = User.create(:name=>'test', :salt=>'', :password=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @sender = Person.create(:name=>'S', :user_id=>@user.id)
    @receiver = Person.create(:name=>'R', :user_id=>@user.id)
  end

  specify "associations should be correct" do
    @gift = Gift.create(:name=>'G', :event_id=>@event.id)
    @gift.senders.should == []
    @gift.receivers.should == []
  end

  specify ".add should add and return a gift with the given event, name, sender ids, receiver ids, sender names, and receiver names" do
    Gift.count.should == 0
    gift = Gift.add(@event, 'G', [@sender.id], [@receiver.id], ['S2'], ['R2'])
    Gift.count.should == 1
    gift.should == Gift.first
    gift.senders.map{|s| s.name}.should == %w'S S2'
    gift.receivers.map{|r| r.name}.should == %w'R R2'
  end

  specify ".add should add new senders and receivers to the event, whether or not they already exist for the user" do
    Gift.count.should == 0
    gift = Gift.add(@event, 'G', [], [], %w'S S2', %w'R R2')
    @event.senders.map{|s| s.name}.should == %w'S S2'
    @event.receivers.map{|r| r.name}.should == %w'R R2'
    @event.gifts.should == [gift]
  end

  specify ".add should return nil and not add a gift if it isn't given at least one sender and at least one receiver" do
    Gift.count.should == 0
    Gift.add(@event, 'G2', [], [], [], []).should == nil
    Gift.count.should == 0
    Gift.add(@event, 'G2', [@sender.id], [], ['S2'], []).should == nil
    Gift.count.should == 0
    Gift.add(@event, 'G2', [], [@receiver.id], [], ['R2']).should == nil
    Gift.count.should == 0
  end
end

describe Person do
  before do
    @user = User.create(:name=>'test', :salt=>'', :password=>'')
    @event = Event.create(:name=>'Christmas', :user_id=>@user.id)
    @person = Person.create(:name=>'P', :user_id=>@user.id)
  end

  specify "associations should be correct" do
    @person.sender_events.should == []
    @person.receiver_events.should == []
    @person.gifts_sent.should == []
    @person.gifts_received.should == []
  end

  specify ".for_user_by_id should find a person with the given id for the given user" do
    Person.for_user_by_id(@user, @person.id).should == @person
  end
  
  specify ".for_user_by_name should return the person for the given user with the given name if such person exists" do
    Person.for_user_by_name(@user, 'P').should == @person
    Person.count.should == 1
  end
  
  specify ".for_user_by_name should create a new person with the given user and name if the user doesn't already have a person with that name" do
    person = Person.for_user_by_name(@user, 'P2')
    Person.count.should == 2
    person.should_not == @person
    person.class.should == Person
  end
  
  specify "#make_receiver should make this person a receiver in the given event" do
    @person.make_receiver(@event).should == @person
    @person.receiver_events.should == [@event]
    @person.make_receiver(@event).should == @person
    @person.reload.receiver_events.should == [@event]
  end
  
  specify "#make_sender should make this person a sender in the given event" do
    @person.make_sender(@event).should == @person
    @person.sender_events.should == [@event]
    @person.make_sender(@event).should == @person
    @person.reload.sender_events.should == [@event]
  end
end

describe User do
  before do
    @user = User.create(:name=>'test', :salt=>'', :password=>'')
  end

  specify "associations should be correct" do
    @user.events.should == []
  end

  specify "#password= should create a new salt" do
    salt = @user.salt
    @user.password = 'blah'
    @user.salt.should_not == salt
    @user.salt.should =~ /\A[0-9a-zA-Z]{40}\z/
  end

  specify "#password= should set the SHA1 password hash based on the salt and password" do
    @user.password = 'blah'
    @user.password.should == Digest::SHA1.new.update(@user.salt).update('blah').hexdigest
  end

  specify ".login_user_id should return nil unless both username and password are present" do
    User.login_user_id(nil, nil).should == nil
    User.login_user_id('default', nil).should == nil
    User.login_user_id(nil, 'blah').should == nil
  end

  specify ".login_user_id should return nil unless a user with a given username exists" do
    User.login_user_id('blah', nil).should == nil
  end

  specify ".login_user_id should return nil unless the password matches for that username" do
    User.login_user_id('test', 'wrong').should == nil
  end

  specify ".login_user_id should return the user's id if the password matches " do
    @user.password = 'blah'
    @user.save
    User.login_user_id('test', 'blah').should == @user.id
  end
end
