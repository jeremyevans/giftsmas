require 'capybara'
require 'capybara/dsl'
require 'capybara/validate_html5'
require 'rack/test'
require_relative 'spec_helper'

Gem.suffix_pattern

require_relative '../giftsmas'

db_name = Giftsmas::DB.get{current_database.function}
raise "Doesn't look like a test database (#{db_name}), not running tests" unless db_name =~ /test\z/

begin
  require 'refrigerator'
rescue LoadError
else
  Refrigerator.freeze_core(:except=>['BasicObject'])
end

Giftsmas::App.plugin :error_handler do |e|
  raise e
end
Capybara.app = Giftsmas::App.freeze.app
Capybara.exact = true

class Minitest::HooksSpec
  include Rack::Test::Methods
  include Capybara::DSL

  def app
    Giftsmas::App
  end

  def create_user(name)
    Giftsmas::User.create(:name=>name, :password=>'valid')
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
    page.current_path.must_equal '/login'
    visit('/choose_event')
    page.current_path.must_equal '/login'
    visit('/manage')
    page.current_path.must_equal '/login'
  end

  specify "should handle an incorrect login" do
    create_user('jeremy')
    visit('/login')
    fill_in 'user', :with=>'jeremy'
    fill_in 'password', :with=>'invalid'
    click_on 'Login'
    current_path.must_equal '/login'

    fill_in 'user', :with=>'jeremy2'
    fill_in 'password', :with=>'valid'
    click_on 'Login'
    current_path.must_equal '/login'
  end

  specify "should handle the login process and creating event" do
    event_page

    event = Giftsmas::Event.first
    event.name.must_equal 'Christmas'
    current_path.must_match %r{\A/add_gift/\d+\z}
  end

  specify "should not add gifts without a sender, receiver, and a name" do
    event_page

    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>''
    click_on 'Add Gift'
    Giftsmas::Gift.count.must_equal 0

    click_link 'Giftsmas: Christmas'
    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>''
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Giftsmas::Gift.count.must_equal 0

    click_link 'Giftsmas: Christmas'
    fill_in 'new_senders', :with=>''
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Giftsmas::Gift.count.must_equal 0
  end

  specify "should add gifts correctly" do
    event_page

    fill_in 'new_senders', :with=>'Jeremy'
    fill_in 'new_receivers', :with=>'Allyson'
    fill_in 'gift', :with=>'Jewelry'
    click_on 'Add Gift'
    Giftsmas::Gift.count.must_equal 1
    gift = Giftsmas::Gift.first
    gift.name.must_equal 'Jewelry'
    gift.senders.map{|s| s.name}.must_equal %w'Jeremy'
    gift.receivers.map{|s| s.name}.must_equal %w'Allyson'
    event = gift.event
    event.senders.map{|s| s.name}.must_equal %w'Jeremy'
    event.receivers.map{|s| s.name}.must_equal %w'Allyson'

    page.find("div.alert").text.must_equal 'Gift Added'

    check 'Jeremy'
    check 'Allyson'
    fill_in 'new_senders', :with=>'Foo,Bar'
    fill_in 'new_receivers', :with=>'Baz,Qux'
    fill_in 'gift', :with=>'FooBar'
    click_on 'Add Gift'

    Giftsmas::Gift.count.must_equal 2
    gift = Giftsmas::Gift[:name=>'FooBar']
    gift.name.must_equal 'FooBar'
    gift.senders.map{|x| x.name}.must_equal %w'Bar Foo Jeremy'
    gift.receivers.map{|x| x.name}.must_equal %w'Allyson Baz Qux'

    page.all("td").map{|s| s.text.chomp}.must_equal ["FooBar", "Bar, Foo, Jeremy", "Allyson, Baz, Qux", "Jewelry", "Jeremy", "Allyson"]
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
    Giftsmas::Event.create(:user_id=>Giftsmas::User.first.id, :name=>'Christmas')
    Giftsmas::Event.create(:user_id=>Giftsmas::User.first.id, :name=>'Birthday')
    login

    select 'Birthday'
    click_on 'Choose Event'
    page.find('.navbar a.navbar-brand').text.must_equal 'Giftsmas: Birthday'

    click_on 'Change Event'
    select 'Christmas'
    click_on 'Choose Event'
    page.find('.navbar a.navbar-brand').text.must_equal 'Giftsmas: Christmas'
  end

  specify "/logout should log the user out" do
    create_user('jeremy')
    login
    click_on 'Logout'
    visit('/')
    page.current_path.must_equal '/login'
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
    
    %w'Event Gift Person'.each do |x|
      %w'browse delete edit search show'.each do |y|
        visit("/#{x}/#{y}")
        page.html.must_include "Giftsmas - #{x} - #{y.capitalize}"
      end
    end
  end

  specify "reports should be correct" do
    event_page
    e = Giftsmas::Event.first
    p1, p2, p3, p4 = [1, 2, 3, 4, 5].collect{|x| Giftsmas::Person.create(:user_id=>e.user_id, :name=>"P#{x}")}
    g1 = Giftsmas::Gift.create(:event_id=>e.id, :name=>'G1')
    g1.add_sender(p1)
    g1.add_receiver(p2)
    g2 = Giftsmas::Gift.create(:event_id=>e.id, :name=>'G2')
    g2.add_sender(p1)
    g2.add_receiver(p2)
    g3 = Giftsmas::Gift.create(:event_id=>e.id, :name=>'G3')
    g3.add_sender(p1)
    g3.add_sender(p3)
    g3.add_receiver(p4)
    g4 = Giftsmas::Gift.create(:event_id=>e.id, :name=>'G4')
    g4.add_sender(p3)
    g4.add_receiver(p2)
    g4.add_receiver(p4)

    click_on 'Reports'
    click_on 'In Chronological Order'
    page.all("table th").map{|s| s.text}.must_equal %w'Time Gift Senders Receivers'
    page.all("table tbody tr").map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.must_equal [%w'G1 P1 P2', %w'G2 P1 P2', ['G3', 'P1, P3', 'P4'], ['G4', 'P3', 'P2, P4']]

    click_on 'Reports'
    click_on 'By Receiver'
    page.all('table caption').map{|s| s.text}.must_equal %w'P2 P4'
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.must_equal ['Time', 'Gift', 'Senders', 'Other Receivers']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.must_equal [['G1', 'P1', ''], ['G2', 'P1', ''], %w'G4 P3 P4']
    table = tables.last
    table.all('th').map{|s| s.text}.must_equal ['Time', 'Gift', 'Senders', 'Other Receivers']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.must_equal [['G3', 'P1, P3', ''], %w'G4 P3 P2']

    click_on 'Reports'
    click_on 'By Sender'
    page.all('table caption').map{|s| s.text}.must_equal %w'P1 P3'
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.must_equal ['Time', 'Gift', 'Receivers', 'Other Senders']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.must_equal [['G1', 'P2', ''], ['G2', 'P2', ''], %w'G3 P4 P3']
    table = tables.last
    table.all('th').map{|s| s.text}.must_equal ['Time', 'Gift', 'Receivers', 'Other Senders']
    table.all('tbody tr').map{|s| s.all('td')[1..-1].map{|s2| s2.text}}.must_equal [%w'G3 P4 P1', ['G4', 'P2, P4', '']]

    click_on 'Reports'
    click_on 'Summary'
    page.find('h3').text.must_equal 'Total Number of Gifts: 4'
    page.all('table caption').map{|s| s.text.chomp}.must_equal ['Totals By Sender', 'Totals By Receiver']
    tables = page.all('table')
    table = tables.first
    table.all('th').map{|s| s.text}.must_equal ['Sender', 'Number of Gifts']
    table.all('tbody tr').map{|s| s.all('td').map{|s2| s2.text}}.must_equal [%w'P1 3', %w'P3 2']
    table = tables.last
    table.all('th').map{|s| s.text}.must_equal ['Receiver', 'Number of Gifts']
    table.all('tbody tr').map{|s| s.all('td').map{|s2| s2.text}}.must_equal [%w'P2 3', %w'P4 2']

    click_on 'Reports'
    click_on 'Summary Crosstab'
    page.all("table th").map{|s| s.text}.must_equal %w'Sender\Receiver P2 P4'
    page.all("table tbody tr").map{|s| s.all('td').map{|s2| s2.text}}.must_equal [%w'P1 2 1', %w'P3 1 2']

    click_on 'Reports'
    click_on 'Thank You Notes'
    page.all("#content > ul > li > ul > li").map{|s| s.text.gsub(/\s+/, '')}.must_equal %w"P1G1G2 P3G4 P1G3 P3G3G4"

    click_on 'Reports'
    click_on 'Comparative'
    page.all("table th").map{|s| s.text}.must_equal %w'Event P2 P4 Total Average'
    page.all("table tbody tr").map{|s| s.all('td').map{|s2| s2.text}}.must_equal [%w'Christmas 3 2 5 2']
  end

  specify "users can't see other other users events, people, or gifts" do
    j = create_user('j')
    je = Giftsmas::Event.create(:user_id=>j.id, :name=>'JE')
    Giftsmas::Person.create(:user_id=>j.id, :name=>'JP')
    Giftsmas::Gift.create(:event_id=>je.id, :name=>'JG')

    event_page
    Giftsmas::Event.exclude(:user_id=>j.id).first
    visit('/choose_event')
    select 'Christmas'
    click_button 'Choose Event'
    click_link 'Associate Receivers'
    page.all("option").size.must_equal 0
    click_link 'Associate Senders'
    page.all("option").size.must_equal 0
    click_link 'Manage'
    click_link 'Events'
    visit "/Event/edit"
    page.all("option").map{|s| s.text}.must_equal ['', 'Christmas']
    click_link 'Manage'
    click_link 'Gifts'
    click_link 'Edit'
    page.all("option").map{|s| s.text}.must_equal ['']
    click_link 'Manage'
    click_link 'People'
    click_link 'Edit'
    page.all("option").map{|s| s.text}.must_equal ['']
    click_link 'Giftsmas'
    select 'Christmas'
    click_button 'Choose Event'
    page.all("option").size.must_equal 0
    visit("/reports/chronological")
    page.find('#content').text.wont_match(/J[EPG]/)
    visit("/reports/by_sender")
    page.find('#content').text.wont_match(/J[EPG]/)
    visit("/reports/by_receiver")
    page.find('#content').text.wont_match(/J[EPG]/)
    visit("/reports/summary")
    page.find('#content').text.wont_match(/J[EPG]/)
    visit("/reports/crosstab")
    page.find('#content').text.wont_match(/J[EPG]/)
    visit("/reports/thank_yous")
    page.find('#content').text.wont_match(/J[EPG]/)
  end
end
