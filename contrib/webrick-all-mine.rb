#!/usr/local/bin/ruby
require 'webrick'
include WEBrick

s = HTTPServer.new(
    :Port            => 2000,
    :DocumentRoot    => Dir::pwd + "/htdocs"
)

## mount subdirectories
require 'hobix/config'
require 'hobix/weblog'
config = File.open( File.expand_path( "~/.hobixrc" ) ) { |f| YAML::load( f ) }
config['weblogs'].each do |name, path|
    weblog = Hobix::Weblog.load( path )
    s.mount("/#{ name }", HTTPServlet::FileHandler, weblog.output_path)
end

trap("INT"){ s.shutdown }
s.start
