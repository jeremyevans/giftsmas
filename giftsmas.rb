require 'roda'

require_relative 'models'
require 'thamble'
require 'tilt/erubi'

module Giftsmas

PersonSplitter = /,/ unless defined?(PersonSplitter)

class App < Roda
  opts[:root] = File.dirname(__FILE__)

  use Rack::Session::Cookie, :secret=>ENV.delete('GIFTSMAS_SECRET')
  plugin :csrf

  plugin :public, :gzip=>true
  plugin :h
  plugin :render, :escape=>true
  plugin :assets,
    :css=>%w'bootstrap.min.css application.scss',
    :css_opts=>{:style=>:compressed, :cache=>false},
    :css_dir=>nil,
    :compiled_path=>nil,
    :compiled_css_dir=>nil,
    :precompiled=>File.expand_path('../compiled_assets.json', __FILE__),
    :prefix=>nil,
    :gzip=>true
  plugin :flash
  plugin :error_handler
  plugin :not_found
  plugin :symbol_views
  plugin :typecast_params
  alias tp typecast_params

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
    request.is path, Integer do |id|
      get_event(id)
      yield
    end
  end

  error do |e|
    case e
    when Roda::RodaPlugins::TypecastParams::Error
      response.status = 400
      view(:content=>"<h1>Invalid parameter submitted: #{h e.param_name}</h1>")
    else
      $stderr.puts "#{e.class}: #{e.message}", e.backtrace
      view(:content=>"<h1>Internal Server Error</h1>")
    end
  end

  not_found do
    view :content=>"<h3>The page you are looking for does not exist.</h3>"
  end

  plugin :rodauth do
    db DB
    enable :login, :logout
    session_key :user_id
    login_param 'user'
    login_label 'User'
    login_column :name
    accounts_table :users
    account_password_hash_column :password_hash
    title_instance_variable :@title
  end

  plugin :autoforme do
    model Event do
      class_display_name 'Event'
      columns [:name]
      order [:name]
      association_links [:gifts]
      mtm_associations [:receivers, :senders]
      session_value :user_id
    end
    model Gift do
      class_display_name 'Gift'
      supported_actions [:browse, :edit, :show, :search, :delete, :mtm_edit]
      columns [:name]
      order [:name]
      mtm_associations [:receivers, :senders]
      association_links [:receivers, :senders]
      session_value :user_id
    end
    model Person do
      class_display_name 'Person'
      columns [:name]
      order [:name]
      association_links [:sender_events, :receiver_events, :gifts_sent, :gifts_received]
      session_value :user_id
    end
  end

  Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  Forme.default_config = :mine

  route do |r|
    r.public
    r.assets
    r.rodauth

    if !session[:user_id] || !(@user = User[session[:user_id]])
      r.redirect('/login')
    end
    
    with_event "add_gift" do
      r.get do
        @recent_gifts = Gift.recent(@event, 5)
        :index
      end

      r.post do
        new_senders = tp.str!('new_senders').split(PersonSplitter).map(&:strip).reject(&:empty?)
        new_receivers = tp.str!('new_receivers').split(PersonSplitter).map(&:strip).reject(&:empty?)
        senders = request.params['senders']
        senders = senders.is_a?(Hash) ? senders.keys : []
        receivers = request.params['receivers']
        receivers = receivers.is_a?(Hash) ? receivers.keys : []
        gift_name = tp.nonempty_str('gift')
        if gift_name && Gift.add(@event, gift_name, senders, receivers, new_senders, new_receivers)
          flash[:notice] = "Gift Added"
        else
          flash[:error] = "Gift Not Added: You must specify a name and at least one sender and receiver."
        end
        r.redirect
      end
    end
      
    r.on "reports", :method=>'get' do
      with_event "event" do
        :reports
      end
    
      with_event 'chronological' do
        @gifts = @event.gifts
        :report_chron
      end
      
      with_event 'crosstab' do
        @headers, @rows = @event.gifts_crosstab
        :report_crosstab
      end
      
      with_event 'summary' do
        @senders, @receivers = @event.gifts_summary
        :report_summary
      end
      
      with_event 'by_sender' do
        @senders = @event.gifts_by_sender
        :report_sender
      end
      
      with_event 'by_receiver' do
        @receivers = @event.gifts_by_receiver
        :report_receiver
      end
      
      with_event 'thank_yous' do
        @receivers = @event.thank_you_notes
        :report_thank_yous
      end

      r.is 'compare' do
        @event_ds = Event.where(:user_id=>@user.id).exclude(:name=>'Test')
        :report_compare
      end
    end
    
    r.root do
      r.redirect '/choose_event'
    end
    
    r.is 'choose_event' do
      r.get do
        :choose_event
      end
      
      r.post do
        e = Event[:user_id=>@user.id, :id=>tp.pos_int!('event_id')]
        r.redirect("/add_gift/#{e.id}", 303)
      end
    end
    
    r.post 'add_event' do
      if name = tp.nonempty_str('name')
        e = Event.create(:user_id=>@user.id, :name=>name)
        r.redirect("/add_gift/#{e.id}", 303)
      else
        flash[:error] = "Must provide a name for the event"
        r.redirect("/choose_event")
      end
    end

    r.get 'manage' do
      :manage
    end

    autoforme
  end
end
end
