#
# = hobix/out/ping.rb
#
# XML-RPC pingt for Hobix.
#
# Copyright (c) 2003-2004 why the lucky stiff
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
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
            link = @link.to_s
            u, link = u.keys.first, u.values.first if Hash === u
            puts "pinging #{ u }..."
            u = URI::parse( u )
            begin
                server = XMLRPC::Client.new( u.host, u.path, u.port )

                begin
                    result = server.call( "weblogUpdates.ping", @title, link )
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
