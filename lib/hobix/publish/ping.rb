#
# = hobix/out/ping.rb
#
# XML-RPC pingt for Hobix.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
#--
# $Id$
#++
require 'hobix/base'
require 'xmlrpc/client'

module Hobix
module Publish
class Ping < Hobix::BasePublish
    def initialize( weblog, urls )
        @title = weblog.title
        @link = weblog.link
        @urls = urls
    end
    def watch
        ['index']
    end
    def publish( page_name )
        @urls.each do |u|
            puts "pinging #{ u }..."
            u = URI::parse( u )
            begin
                server = XMLRPC::Client.new( u.host, u.path, u.port )

                begin
                    result = server.call( "weblogUpdates.ping", @title, @link )
                rescue XMLRPC::FaultException => e
                    puts "Error: "
                    puts e.faultCode
                    puts e.faultString
                end
            rescue Exception => e
                puts "Error: #{ e.message }"
            end
        end
    end
end
end
end
