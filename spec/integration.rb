ENV['GIFTSMAS_TEST'] = '1'
GIFTSMAS_ENV = :test
require 'rubygems'
require 'capybara'
require 'capybara/dsl'
require 'capybara/rspec/matchers'
require 'rack/test'
$: << File.dirname(File.dirname(__FILE__))
require 'giftsmas'
require File.expand_path("rspec_helper", File.dirname(__FILE__))

Capybara.app = Giftsmas.app

class RSPEC_EXAMPLE_GROUP
  include Rack::Test::Methods
  include Capybara::DSL
  include Capybara::RSpecMatchers

  def app
    APP
  end

  def create_user(name)
    User.create(:name=>name, :password=>'valid')
  end

  def login
    visit('/login')
    fill_in 'user', :with=>'jeremy'
    fill_in 'password', :with=>'valid'
    click_on 'Login'
  end

  def event_page
    create_user('jeremy')
    login
    fill_in 'name', :with=>'Christmas'
    click_on 'Create New Event'
  end
end

describe "Giftsmas" do
  specify "should handle pages that require logins" do
    visit('/')
    page.current_path.should == '/login'
    visit('/choose_event')
    page.current_path.should == '/login'
    visit('/manage')
    page.current_path.should == '/login'
  end

  specify "should handle an incorrect login" do
    create_user('jeremy')
    visit('/login')
    fill_in 'user', :with=>'jeremy'
    fill_in 'password', :with=>'invalid'
    click_on 'Login'
    current_path.should == '/login'

    fill_in 'user', :with=>'jeremy2'
    fill_in 'password', :with=>'valid'
    click_on 'Login'
    current_path.should == '/login'
  end

  specify "should handle the login process and creating event" do
    event_page

    event = Event.first
    event.name.should == 'Christmas'
    current_path.should =~ %r{\A/add_gift/\d+\z}
  end

  specify "should not add gifts without a sender, receiver, and a name" do
    event_page

    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>''
    click_on 'Add Gift'
    Gift.count.should == 0

    click_link 'Giftsmas: Christmas'
    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>''
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Gift.count.should == 0

    click_link 'Giftsmas: Christmas'
    fill_in 'new_senders', :with=>''
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Gift.count.should == 0
  end

  specify "should add gifts correctly" do
    event_page

    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Gift.count.should == 1
    gift = Gift.first
    gift.name.should == 'Jewelry'
    gift.senders.map{|s| s.name}.should == %w'Jeremy'
    gift.receivers.map{|s| s.name}.should == %w'Allyson'
    event = gift.event
    event.senders.map{|s| s.name}.should == %w'Jeremy'
    event.receivers.map{|s| s.name}.should == %w'Allyson'

    page.find("div.alert").text.should == 'Gift Added'

    check 'Jeremy'
    check 'Allyson'
    fill_in 'new_senders', :with=>'Foo,Bar'
    fill_in 'new_receivers', :with=>'Baz,Qux'
    fill_in 'gift', :with=>'FooBar'
    click_on 'Add Gift'

    Gift.count.should == 2
    gift = Gift[:name=>'FooBar']
    gift.name.should == 'FooBar'
    gift.senders.map{|x| x.name}.should == %w'Bar Foo Jeremy'
    gift.receivers.map{|x| x.name}.should == %w'Allyson Baz Qux'

    page.all("td").map{|s| s.text.chomp}.should == ["FooBar", "Bar, Foo, Jeremy", "Allyson, Baz, Qux", "Jewelry", "Jeremy", "Allyson"]
    click_link 'FooBar'
    click_button 'Update'
    click_link 'Giftsmas: Christmas'
    click_link 'Jeremy'
    click_button 'Update'
    click_link 'Giftsmas: Christmas'
    click_link 'Allyson'
    click_button 'Update'
  end

  specify "/choose_event should change the current event" do
    create_user('jeremy')
    e1 = Event.create(:user_id=>User.first.id, :name=>'Christmas')
    e2 = Event.create(:user_id=>User.first.id, :name=>'Birthday')
    login

    select 'Birthday'
    click_on 'Choose Event'
    page.find('.navbar a.navbar-brand').text.should == 'Giftsmas: Birthday'

    click_on 'Change Event'
    select 'Christmas'
    click_on 'Choose Event'
    page.find('.navbar a.navbar-brand').text.should == 'Giftsmas: Christmas'
  end

  specify "/logout should log the user out" do
    create_user('jeremy')
    login
    click_on 'Logout'
    visit('/')
    page.current_path.should == '/login'
  end

  specify "scaffolded forms should be available" do
    event_page
    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'

    click_on 'Associate Receivers'
    select 'Jeremy'
    click_on 'Update'

    click_on 'Associate Senders'
    select 'Allyson'
    click_on 'Update'
    
    %w'event gift person'.each do |x|
      %w'browse new delete edit merge search show'.each do |y|
        model_name = x.tap do |a| a[0] = a[0].upcase end
        visit("#{model_name}/#{y}")
        page.title.should_not be_nil
      end
    end
  end

  specify "reports should be correct" do
    event_page
    e = Event.first
    p1, p2, p3, p4, p5 = [1, 2, 3, 4, 5].collect{|x| Person.create(:user_id=>e.user_id, :name=>"P#{x}")}
    g1 = Gift.create(:event_id=>e.id, :name=>'G1')
    g1.add_sender(p1)
    g1.add_receiver(p2)
    g2 = Gift.create(:event_id=>e.id, :name=>'G2')
    g2.add_sender(p1)
    g2.add_receiver(p2)
    g3 = Gift.create(:event_id=>e.id, :name=>'G3')
    g3.add_sender(p1)
    g3.add_sender(p3)
    g3.add_receiver(p4)
    g4 = Gift.create(:event_id=>e.id, :name=>'G4')
    g4.add_sender(p3)
    g4.add_receiver(p2)
    g4.add_receiver(p4)

    click_on 'Reports'
    click_on 'Chronological'
    page.all("table th").map{|s| s.text}.should == %w'Time Gift Senders Receivers'
    page.all("table tbody tr").map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.should == [%w'G1 P1 P2', %w'G2 P1 P2', ['G3', 'P1, P3', 'P4'], ['G4', 'P3', 'P2, P4']]

    click_on 'Reports'
    click_on 'By Receiver'
    page.all('table caption').map{|s| s.text}.should == %w'P2 P4'
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.should == ['Time', 'Gift', 'Senders', 'Other Receivers']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.should == [['G1', 'P1', ''], ['G2', 'P1', ''], %w'G4 P3 P4']
    table = tables.last
    table.all('th').map{|s| s.text}.should == ['Time', 'Gift', 'Senders', 'Other Receivers']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.should == [['G3', 'P1, P3', ''], %w'G4 P3 P2']

    click_on 'Reports'
    click_on 'By Sender'
    page.all('table caption').map{|s| s.text}.should == %w'P1 P3'
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.should == ['Time', 'Gift', 'Receivers', 'Other Senders']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.should == [['G1', 'P2', ''], ['G2', 'P2', ''], %w'G3 P4 P3']
    table = tables.last
    table.all('th').map{|s| s.text}.should == ['Time', 'Gift', 'Receivers', 'Other Senders']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.should == [%w'G3 P4 P1', ['G4', 'P2, P4', '']]

    click_on 'Reports'
    click_on 'Summary'
    page.find('h3').text.should == 'Total Number of Gifts: 4'
    page.all('table caption').map{|s| s.text.chomp}.should == ['Totals By Sender', 'Totals By Receiver']
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.should == ['Sender', 'Number of Gifts']
    table.all('tbody tr').map{|s| s.all('td').map{|s2| s2.text}}.should == [%w'P1 3', %w'P3 2']
    table = tables.last
    table.all('th').map{|s| s.text}.should == ['Receiver', 'Number of Gifts']
    table.all('tbody tr').map{|s| s.all('td').map{|s2| s2.text}}.should == [%w'P2 3', %w'P4 2']

    click_on 'Reports'
    click_on 'Summary Crosstab'
    page.all("table th").map{|s| s.text}.should == %w'Sender\Receiver P2 P4'
    page.all("table tbody tr").map{|s| s.all('td').map{|s2| s2.text}}.should == [%w'P1 2 1', %w'P3 1 2']

    click_on 'Reports'
    click_on 'Thank You Notes'
    page.all("#content > ul > li > ul > li").map{|s| s.text.gsub(/\s+/, '')}.should == %w"P1G1G2 P3G4 P1G3 P3G3G4"

    click_on 'Reports'
    click_on 'Comparative'
    page.all("table th").map{|s| s.text}.should == %w'Event P2 P4 Total Average'
    page.all("table tbody tr").map{|s| s.all('td').map{|s2| s2.text}}.should == [%w'Christmas 3 2 5 2']
  end

  specify "users can't see other other users events, people, or gifts" do
    j = create_user('j')
    je = Event.create(:user_id=>j.id, :name=>'JE')
    jp = Person.create(:user_id=>j.id, :name=>'JP')
    jg = Gift.create(:event_id=>je.id, :name=>'JG')

    event_page
    jeremye = Event.exclude(:user_id=>j.id).first
    visit('/choose_event')
    select 'Christmas'
    click_button 'Choose Event'
    click_link 'Associate Receivers'
    page.all("option").size.should == 0
    click_link 'Associate Senders'
    page.all("option").size.should == 0
    click_link 'Manage'
    click_link 'Events'
    click_link 'Edit', match: :first
    page.all("option").map{|s| s.text}.should == ['', 'Christmas']
    click_link 'Manage'
    click_link 'Gifts'
    click_link 'Edit'
    page.all("option").map{|s| s.text}.should == ['']
    click_link 'Manage'
    click_link 'People'
    click_link 'Edit'
    page.all("option").map{|s| s.text}.should == ['']
    click_link 'Giftsmas'
    select 'Christmas'
    click_button 'Choose Event'
    page.all("option").size.should == 0
    visit("/reports/chronological")
    page.find('#content').text.should_not =~ /J[EPG]/
    visit("/reports/by_sender")
    page.find('#content').text.should_not =~ /J[EPG]/
    visit("/reports/by_receiver")
    page.find('#content').text.should_not =~ /J[EPG]/
    visit("/reports/summary")
    page.find('#content').text.should_not =~ /J[EPG]/
    visit("/reports/crosstab")
    page.find('#content').text.should_not =~ /J[EPG]/
    visit("/reports/thank_yous")
    page.find('#content').text.should_not =~ /J[EPG]/
  end
end
