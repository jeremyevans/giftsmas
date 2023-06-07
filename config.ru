Encoding.default_internal = Encoding.default_external = 'UTF-8'
require ::File.expand_path('../giftsmas',  __FILE__)
run Giftsmas::App.freeze.app

require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
Tilt.finalize!

begin
  require 'refrigerator'
rescue LoadError
else
  Refrigerator.freeze_core(:except=>['BasicObject'])
end
