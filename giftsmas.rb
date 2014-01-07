#!/usr/bin/env ruby
require 'rubygems'
require 'erb'
require 'sinatra/base'
require 'cgi'
require 'models'
require 'rack/csrf'
require 'sinatra/flash'

PersonSplitter = /,/ unless defined?(PersonSplitter)
SECRET_FILE = File.join(File.dirname(__FILE__), 'giftsmas.secret')
if ENV['GIFTSMAS_SECRET']
  SECRET = ENV['GIFTSMAS_SECRET']
elsif File.file?(SECRET_FILE)
  SECRET = File.read(SECRET_FILE)
else
  SECRET = nil
end

if ENV['RACK_ENV'] == 'development'
  class Tilt::Cache
    def fetch(*)
      yield
    end
  end
end

class Giftsmas < Sinatra::Base
  set(:appfile=>'giftsmas.rb', :views=>'views')
  disable :run

  class FileServer
    def initialize(app, root)
      @app = app
      @rfile = Rack::File.new(root)
    end
    def call(env)
      res = @rfile.call(env)
      res[0] == 200 ? res : @app.call(env)
    end
  end

  use FileServer, 'public'
  use Rack::Session::Cookie, :secret=>SECRET
  use Rack::Csrf

  register Sinatra::Flash

  def h(text)
    CGI.escapeHTML(text)
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

  def get_event
    @event = Event[:user_id=>@user.id, :id=>params[:event_id].to_i] if params[:event_id]
    redirect('/choose_event', 303) unless @event
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

  def self.with_event(verb, path, &block)
    send verb, path do
      get_event
      instance_eval(&block)
    end
  end

  def self.event_get(path, &block)
    with_event(:get, path, &block)
  end

  def self.event_post(path, &block)
    with_event(:post, path, &block)
  end
  
  error do
    e = request.env['sinatra.error']
    puts e.message
    e.backtrace.each{|x| puts x}
    render(:erb, "<h3>Oops, an error occurred.</h3>", :layout=>:layout)
  end
  
  not_found do
    render(:erb, "<h3>The page you are looking for does not exist.</h3>")
  end

  before do
    unless %w'/application.css /favicon.ico /login /logout'.include?(env['PATH_INFO'])
      redirect('/login', 303) if !session[:user_id] or !(@user = User[session[:user_id]])
    end
  end

  event_get '/add_gift/:event_id' do
    @recent_gifts = Gift.recent(@event, 5)
    render :erb, :index
  end
  
  event_post '/add_gift/:event_id' do
    new_senders = params[:new_senders].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
    new_receivers = params[:new_receivers].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
    senders = params[:senders].is_a?(Hash) ? params[:senders].keys : []
    receivers = params[:receivers].is_a?(Hash) ? params[:receivers].keys : []
    if gift = Gift.add(@event, params[:gift].to_s.strip, senders, receivers, new_senders, new_receivers)
      flash[:notice] = "Gift Added"
    else
      flash[:error] = "Gift Not Added: You must specify a name and at least one sender and receiver."
    end
    redirect("/add_gift/#{@event.id}", 303)
  end
  
  event_get '/reports/event/:event_id' do
    render :erb, :reports
  end
  
  event_get '/reports/chronological/:event_id' do
    @gifts = @event.gifts
    render :erb, :report_chron
  end
  
  event_get '/reports/crosstab/:event_id' do
    @headers, @rows = @event.gifts_crosstab
    render :erb, :report_crosstab
  end
  
  event_get '/reports/summary/:event_id' do
    @senders, @receivers = @event.gifts_summary
    render :erb, :report_summary
  end
  
  event_get '/reports/by_sender/:event_id' do
    @senders = @event.gifts_by_sender
    render :erb, :report_sender
  end
  
  event_get '/reports/by_receiver/:event_id' do
    @receivers = @event.gifts_by_receiver
    render :erb, :report_receiver
  end
  
  event_get '/reports/thank_yous/:event_id' do
    @receivers = @event.thank_you_notes
    render :erb, :report_thank_yous
  end
  
  get '/login' do
    render :erb, :login
  end
  
  post '/login' do
    if i = User.login_user_id(params[:user], params[:password])
      session[:user_id] = i
      redirect('/choose_event', 303)
    else
      flash[:error] = 'Bad User/Password'
      redirect('/login', 303)
    end
  end
  
  post '/logout' do
    session.clear
    redirect '/login'
  end

  get '/' do
    redirect '/choose_event'
  end
  
  get '/choose_event' do
    render :erb, :choose_event
  end
  
  post '/choose_event' do
    e = Event[:user_id=>@user.id, :id=>params[:event_id].to_i]
    redirect("/add_gift/#{e.id}", 303)
  end
  
  post '/add_event' do
    name = params[:name].to_s.strip
    if name.empty?
      flash[:error] = "Must provide a name for the event"
      redirect("/choose_event")
    else
      e = Event.create(:user_id=>@user.id, :name=>params[:name])
      redirect("/add_gift/#{e.id}", 303)
    end
  end

  get '/manage' do
    erb :manage
  end

  require 'autoforme'
  Forme.register_config(:mine, :base=>:default, :labeler=>:explicit, :wrapper=>:div)
  Forme.default_config = :mine

  AutoForme.for(:sinatra, self) do
    model_type :sequel

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
end
