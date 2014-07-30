#!/usr/bin/env ruby
require 'rubygems'
require 'erb'
require 'roda'
require 'models'
require 'rack/csrf'
require 'thamble'
require 'autoforme'
require 'rack/protection'

PersonSplitter = /,/ unless defined?(PersonSplitter)
SECRET_FILE = File.join(File.dirname(__FILE__), 'giftsmas.secret')
if ENV['GIFTSMAS_SECRET']
  SECRET = ENV['GIFTSMAS_SECRET']
elsif File.file?(SECRET_FILE)
  SECRET = File.read(SECRET_FILE)
else
  SECRET = nil
end

class Giftsmas < Roda
  use Rack::Session::Cookie, :secret=>SECRET
  use Rack::Csrf
  use Rack::Static, :urls=>%w'/bootstrap.min.css /application.css /favicon.ico', :root=>'public'
  use Rack::Protection

  plugin :h
  plugin :render
  plugin :flash
  plugin :error_handler
  plugin :not_found

  def html_opts(hash)
    hash.map{|k,v| "#{k}=\"#{h(v)}\""}.join(' ')
  end
  
  def select(name, options, opts={})
    "<select name=\"#{name}\" #{html_opts(opts)}>\n#{options.map{|t,v| "<option value=\"#{v}\">#{h(t)}</option>"}.join("\n")}\n</select>"
  end

  def model_select(name, objects, opts={})
    meth = opts.delete(:meth)||:name
    select(name, objects.map{|o| [o.send(meth), o.id]}, opts)
  end

  def get_event(id)
    @event = Event[:user_id=>@user.id, :id=>id.to_i] if id
    request.redirect('/choose_event', 303) unless @event
  end

  def current_event
    if @event
      @event
    elsif @autoforme_action
      if @autoforme_action.request.model == 'Event' && @autoforme_action.request.id
        @event = Event[:user_id=>@user.id, :id=>@autoforme_action.request.id]
      elsif @autoforme_action.request.model == 'Gift' && @autoforme_action.request.id
        @event = Gift[:user_id=>@user.id, :id=>@autoforme_action.request.id].event
      end
    end
  end

  def with_event(path)
    request.is path do |id|
      get_event(id)
      yield
    end
  end

  error do |e|
    $stderr.puts e.message
    e.backtrace.each{|x| $stderr.puts x}
    view :inline=>"<h3>Oops, an error occurred.</h3>"
  end

  not_found do
    view :inline=>"<h3>The page you are looking for does not exist.</h3>"
  end

  Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  Forme.default_config = :mine

  plugin :autoforme do
    model Event do
      columns [:name]
      order [:name]
      association_links [:gifts]
      mtm_associations [:receivers, :senders]
      session_value :user_id
    end
    model Gift do
      supported_actions [:browse, :edit, :show, :search, :delete, :mtm_edit]
      columns [:name]
      order [:name]
      mtm_associations [:receivers, :senders]
      association_links [:receivers, :senders]
      session_value :user_id
    end
    model Person do
      columns [:name]
      order [:name]
      association_links [:sender_events, :receiver_events, :gifts_sent, :gifts_received]
      session_value :user_id
    end
  end

  route do |r|
    r.is 'login' do
      r.get do
        view :login
      end

      r.post do 
        if i = User.login_user_id(r['user'], r['password'])
          session[:user_id] = i
          r.redirect('/choose_event', 303)
        else
          flash[:error] = 'Bad User/Password'
          r.redirect('/login', 303)
        end
      end
    end
    
    r.post 'logout' do
      session.clear
      r.redirect '/login'
    end

    if !session[:user_id] || !(@user = User[session[:user_id]])
      r.redirect('/login', 303)
    end
    
    with_event "add_gift/:event_id" do
      r.get do
        @recent_gifts = Gift.recent(@event, 5)
        view :index
      end

      r.post do
        new_senders = request['new_senders'].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
        new_receivers = request['new_receivers'].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
        senders = request['senders'].is_a?(Hash) ? request['senders'].keys : []
        receivers = request['receivers'].is_a?(Hash) ? request['receivers'].keys : []
        if gift = Gift.add(@event, request['gift'].to_s.strip, senders, receivers, new_senders, new_receivers)
          flash[:notice] = "Gift Added"
        else
          flash[:error] = "Gift Not Added: You must specify a name and at least one sender and receiver."
        end
        r.redirect("/add_gift/#{@event.id}", 303)
      end
    end
      
    r.on "reports", :method=>'get' do
      with_event "event/:event_id" do
        view :reports
      end
    
      with_event 'chronological/:event_id' do
        @gifts = @event.gifts
        view :report_chron
      end
      
      with_event 'crosstab/:event_id' do
        @headers, @rows = @event.gifts_crosstab
        view :report_crosstab
      end
      
      with_event 'summary/:event_id' do
        @senders, @receivers = @event.gifts_summary
        view :report_summary
      end
      
      with_event 'by_sender/:event_id' do
        @senders = @event.gifts_by_sender
        view :report_sender
      end
      
      with_event 'by_receiver/:event_id' do
        @receivers = @event.gifts_by_receiver
        view :report_receiver
      end
      
      with_event 'thank_yous/:event_id' do
        @receivers = @event.thank_you_notes
        view :report_thank_yous
      end
    end
    
    r.get "" do
      r.redirect '/choose_event'
    end
    
    r.is 'choose_event' do
      r.get do
        view :choose_event
      end
      
      r.post do
        e = Event[:user_id=>@user.id, :id=>request['event_id'].to_i]
        r.redirect("/add_gift/#{e.id}", 303)
      end
    end
    
    r.post 'add_event' do
      name = request['name'].to_s.strip
      if name.empty?
        flash[:error] = "Must provide a name for the event"
        r.redirect("/choose_event")
      else
        e = Event.create(:user_id=>@user.id, :name=>request['name'])
        r.redirect("/add_gift/#{e.id}", 303)
      end
    end

    r.get 'manage' do
      view :manage
    end

    autoforme
  end
end
