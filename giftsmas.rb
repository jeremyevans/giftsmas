#!/usr/bin/env ruby
require 'rubygems'
require 'erb'
require 'sinatra/base'
require 'cgi'
require 'models'
require 'scaffolding_extensions'
require 'rack/csrf'

ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS[:text_to_string] = true
PersonSplitter = /,/ unless defined?(PersonSplitter)
SECRET_FILE = File.join(File.dirname(__FILE__), 'giftsmas.secret')
if ENV['GIFTSMAS_SECRET']
  SECRET = ENV['GIFTSMAS_SECRET']
elsif File.file?(SECRET_FILE)
  SECRET = File.read(SECRET_FILE)
else
  SECRET = nil
end

class Sinatra::Base
  set(:appfile=>'giftsmas.rb', :views=>'views')
  disable :run
  use Rack::Session::Cookie, :secret=>SECRET
  use Rack::Csrf

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
    @flash = session.delete(:flash)
    unless %w'/application.css /favicon.ico /login /logout'.include?(env['PATH_INFO'])
      redirect('/login', 303) if !session[:user_id] or !(@user = User[session[:user_id]])
      unless %w'/choose_event /add_event'.include?(env['PATH_INFO'])
        @event = Event[session[:event_id]] if session[:event_id]
        redirect('/choose_event', 303) unless @event
      end
    end
  end
end

class Giftsmas < Sinatra::Base
  get '/' do
    @recent_gifts = Gift.recent(@event, 5)
    render :erb, :index
  end
  
  post '/add_gift' do
    new_senders = params[:new_senders].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
    new_receivers = params[:new_receivers].split(PersonSplitter).map{|name| name.strip}.reject{|name| name.empty?}
    senders = params[:senders].is_a?(Hash) ? params[:senders].keys : []
    receivers = params[:receivers].is_a?(Hash) ? params[:receivers].keys : []
    session[:flash] = if gift = Gift.add(@event, params[:gift].to_s.strip, senders, receivers, new_senders, new_receivers)
      "Gift Added: #{h gift.name}<br />Senders: #{gift.senders.map{|s| s.name}.join(', ')}<br />Receivers: #{gift.receivers.map{|s| s.name}.join(', ')}"
    else
      "Gift Not Added: You must specify a name and at least one sender and receiver."
    end
    redirect('/', 303)
  end
  
  get '/reports' do
    render :erb, :reports
  end
  
  get '/reports/chronological' do
    @gifts = @event.gifts
    render :erb, :report_chron
  end
  
  get '/reports/crosstab' do
    @headers, @rows = @event.gifts_crosstab
    render :erb, :report_crosstab
  end
  
  get '/reports/summary' do
    @senders, @receivers = @event.gifts_summary
    render :erb, :report_summary
  end
  
  get '/reports/by_sender' do
    @senders = @event.gifts_by_sender
    render :erb, :report_sender
  end
  
  get '/reports/by_receiver' do
    @receivers = @event.gifts_by_receiver
    render :erb, :report_receiver
  end
  
  get '/reports/thank_yous' do
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
      session[:flash] = 'Bad User/Password'
      redirect('/login', 303)
    end
  end
  
  post '/logout' do
    session.clear
    redirect '/login'
  end
  
  get '/choose_event' do
    render :erb, :choose_event
  end
  
  post '/choose_event' do
    e = Event[:user_id=>@user.id, :id=>params[:event_id].to_i]
    session[:event_id] = e.id
    redirect('/', 303)
  end
  
  post '/add_event' do
    name = params[:name].to_s.strip
    if name.empty?
      session[:flash] = "Must provide a name for the event"
    else
      e = Event.create(:user_id=>@user.id, :name=>params[:name])
      session[:event_id] = e.id
    end
    redirect('/', 303)
  end
end

class GiftsmasSE < Sinatra::Base
  get %r{\A/(index/*)?\z} do
    render :erb, :manage
  end
  scaffold_all_models :only=>[Event, Gift, Person]

  def scaffold_token_tag
    Rack::Csrf.tag(env)
  end
end

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

GiftsmasApp = Rack::Builder.app do
  use FileServer, 'public'
  map "/" do
    run Giftsmas
  end
  map "/manage" do
    run GiftsmasSE
  end
end
