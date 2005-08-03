#
# = hobix/facets/trackbacks.rb
#
# Hobix command-line weblog system, support for trackbacks.
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

require 'hobix/entry'

module Hobix
module Facets

# The Trackbacks plugin adds support for the TrackBack specification
# (http://www.sixapart.com/pronet/docs/trackback_spec).
#
# Add this require to your hobix.yaml:
#
#   requires:
#   - hobix/trackbacks
#
class Trackbacks < BaseFacet
    def self.trackback_fields; ['url','title', 'excerpt', 'blog_name']; end
    def self.trackback_class; Hobix::Trackback; end

    def initialize( weblog, defaults = {} )
        @weblog = weblog
    end
    def get app
        if app.respond_to? :action_uri
            action, entry_id = app.action_uri.split( '/', 2 )
            case action
            when "trackback"
                # Validate
                on_entry = @weblog.storage.load_entry( entry_id ) rescue nil
                return send_trackback_response( app, false, 'No such entry' ) if on_entry.nil?

                # Create a trackback comment
                trackback = Trackbacks.trackback_class.new do |t|
                    Trackbacks.trackback_fields.each do |tf|
                      t.method( "#{tf}=" ).call( app._POST[tf].to_s )
                    end
                    return send_trackback_response( app, false, 'Missing URL field' ) if (t.url || '').empty?
                    t.created = Time.now
                    t.ipaddress = app.remote_addr
                end

                # Save the trackback, upgen
                @weblog.storage.append_to_attachment( entry_id, 'trackbacks', trackback )
                @weblog.regenerate :update

                # Send response
                send_trackback_response( app, true )
                return true
            end
        end
    end

    def send_trackback_response(app, ok = true, message = nil)
      app.content_type = 'text/xml'
      app.puts %{<?xml version="1.0" encoding="UTF-8"?>
        <response>
          <error>%d</error>
          %s
        </response>
      } % [ok ? 0 : 1, message ? %{<message>#{message}</message>} : '']
      true
    end
end

end
end
