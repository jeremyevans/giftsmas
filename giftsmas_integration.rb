require 'giftsmas'
puts "Starting"
Rack::Handler.get('mongrel').run(GiftsmasApp, :Host=>'0.0.0.0', :Port=>3003) do |server|
  trap(:INT) do
    server.stop
    puts "Stopping"
  end
end
