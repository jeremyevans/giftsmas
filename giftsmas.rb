# frozen_string_literal: true
require_relative 'models'

require 'roda'
require 'thamble'
require 'tilt'
require 'tilt/erubi'
require 'tilt/string'

module Giftsmas

PersonSplitter = /,/ unless defined?(PersonSplitter)

class App < Roda
  def self.freeze
    Model.freeze_descendents
    DB.freeze
    super
  end

  opts[:root] = File.dirname(__FILE__)
  opts[:check_dynamic_arity] = false
  opts[:check_arity] = :warn

  plugin :direct_call
  plugin :route_csrf
  plugin :public, :gzip=>true
  plugin :h
  plugin :r
  plugin :render, :escape=>true, :template_opts=>{:chain_appends=>true, :freeze=>true, :skip_compiled_encoding_detection=>true}
  plugin :assets,
    :css=>%w'application.scss',
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
  plugin :disallow_file_uploads
  plugin :symbol_views
  plugin :request_aref, :raise
  plugin :Integer_matcher_max
  plugin :typecast_params_sized_integers, :sizes=>[64], :default_size=>64
  alias tp typecast_params

  logger = case ENV['RACK_ENV']
  when 'development', 'test' # Remove development after Unicorn 5.5+
    Class.new{def write(_) end}.new
  else
    $stderr
  end
  plugin :common_logger, logger

  if ENV['RACK_ENV'] == 'development'
    plugin :exception_page
    class RodaRequest
      def assets
        exception_page_assets 
        super
      end
    end
  end

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

  error do |e|
    case e
    when Roda::RodaPlugins::TypecastParams::Error
      response.status = 400
      view(:content=>"<h1>Invalid parameter submitted: #{h e.param_name}</h1>")
    else
      $stderr.puts "#{e.class}: #{e.message}", e.backtrace
      next exception_page(e, :assets=>true) if ENV['RACK_ENV'] == 'development'
      view(:content=>"<h1>Internal Server Error</h1>")
    end
  end

  not_found do
    view :content=>"<h3>The page you are looking for does not exist.</h3>"
  end

  plugin :rodauth, :csrf=>:route_csrf do
    db DB
    enable :login, :logout
    session_key 'user_id'
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
      session_value 'user_id'
    end
    model Gift do
      class_display_name 'Gift'
      supported_actions [:browse, :edit, :show, :search, :delete, :mtm_edit]
      columns [:name]
      order [:name]
      mtm_associations [:receivers, :senders]
      association_links [:receivers, :senders]
      session_value 'user_id'
    end
    model Person do
      class_display_name 'Person'
      columns [:name]
      order [:name]
      association_links [:sender_events, :receiver_events, :gifts_sent, :gifts_received]
      session_value 'user_id'
    end
  end

  Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  Forme.default_config = :mine

  plugin :content_security_policy do |csp|
    csp.default_src :none
    csp.style_src :self, :unsafe_inline
    csp.img_src :self
    csp.form_action :self
    csp.base_uri :none
    csp.frame_ancestors :none
  end

  plugin :sessions,
    :key=>'giftsmas.session',
    :secret=>ENV.delete('GIFTSMAS_SESSION_SECRET')

  route do |r|
    r.public
    r.assets
    r.rodauth
    check_csrf!
    rodauth.require_authentication
    @user = User[session['user_id']]
    
    r.root do 
      r.redirect '/choose_event'
    end

    r.get 'manage' do
      :manage
    end

    r.is 'choose_event' do
      r.get do
        :choose_event
      end
      
      r.post do
        e = Event[:user_id=>@user.id, :id=>tp.pos_int!('event_id')]
        r.redirect("/event/#{e.id}/add_gift", 303)
      end
    end
    
    r.post 'add_event' do
      if name = tp.nonempty_str('name')
        e = Event.create(:user_id=>@user.id, :name=>name)
        r.redirect("/event/#{e.id}/add_gift", 303)
      else
        flash['error'] = "Must provide a name for the event"
        r.redirect("/choose_event")
      end
    end

    r.on "event", Integer do |event_id|
      next unless @event = Event[:user_id=>@user.id, :id=>event_id]

      r.is "add_gift" do
        r.get do
          @recent_gifts = Gift.recent(@event, 5)
          :index
        end

        r.post do
          new_senders = tp.str!('new_senders').split(PersonSplitter).map(&:strip).reject(&:empty?)
          new_receivers = tp.str!('new_receivers').split(PersonSplitter).map(&:strip).reject(&:empty?)
          senders = r.params['senders']
          senders = senders.is_a?(Hash) ? senders.keys : []
          receivers = r.params['receivers']
          receivers = receivers.is_a?(Hash) ? receivers.keys : []
          gift_name = tp.nonempty_str('gift')
          if gift_name && Gift.add(@event, gift_name, senders, receivers, new_senders, new_receivers)
            flash['notice'] = "Gift Added"
          else
            flash['error'] = "Gift Not Added: You must specify a name and at least one sender and receiver."
          end
          r.redirect
        end
      end

      r.on "reports", :method=>'get' do
        r.is do 
          :reports
        end
        
        r.is 'chronological' do
          @gifts = @event.gifts
          :report_chron
        end
        
        r.is 'crosstab' do
          @headers, @rows = @event.gifts_crosstab
          :report_crosstab
        end
        
        r.is 'summary' do
          @senders, @receivers = @event.gifts_summary
          :report_summary
        end
        
        r.is 'by_sender' do
          @senders = @event.gifts_by_sender
          :report_sender
        end
        
        r.is 'by_receiver' do
          @receivers = @event.gifts_by_receiver
          :report_receiver
        end
        
        r.is 'thank_yous' do
          @receivers = @event.thank_you_notes
          :report_thank_yous
        end
      end
    end

    r.get 'compare' do
      @event_ds = Event.where(:user_id=>@user.id).exclude(:name=>'Test')
      :report_compare
    end

    autoforme
  end
end
end
