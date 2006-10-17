#
# = hobix/facets/comments.rb
#
# Hobix command-line weblog system, API for comments.
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

# The Comments plugin adds a remote API for adding comments.
# Basically, to add comments to your site, ensure the plugin
# is loaded within your hobix.yaml `requires' list:
#
#   requires:
#   - hobix/facets/comments
#
class Comments < BaseFacet
    def self.form_field( name ); "hobix_comment:#{ name }" end
    def self.comment_fields; ['author', 'content']; end
    def self.comment_class; Hobix::Comment end

    def initialize( weblog, defaults = {} )
        @weblog = weblog
    end
    def get app
        if app.respond_to? :action_uri
            action, entry_id = app.action_uri.split( '/', 2 )
            case action
            when "comment"
                # Create the comment entry
                on_entry = @weblog.storage.load_entry( entry_id )
                comment = Comments.comment_class.new do |c|
                    Comments.comment_fields.each do |cf|
                        getf = Comments.form_field cf
                        if app._POST[getf].to_s.empty?
                            app.puts "Missing field `#{ getf }'.  Please back up and try again."
                            return true
                        end
                        c.method( "#{ cf }=" ).call( app._POST[getf] )
                    end
                    c.created = Time.now
                    c.ipaddress = app.remote_addr
                end

               # A quick hack to try akismet content spam checking
               if @weblog.requires.detect{ |i| i['hobix/plugin/akismet'] }         
                   @akismet = Akismet.new(@weblog.link, AkismetKey.key)
                   if @akismet.verifyAPIKey
                       if @akismet.commentCheck(
                               app.remote_addr,                            # remote IP
                               app.get_request_header('User-Agent'),       # user agent
                               app.get_request_header('Referer'),          # http referer
                               '',                                         # permalink
                               'comment',                                  # comment type
                               app._POST['hobix_comment:author'].to_s,     # author name
                               '',                                         # author email
                               '',                                         # author url
                               app._POST['hobix_comment:comment'].to_s,    # comment text
                               {})                                         # other
                           app.puts( "Sorry, that smelled like spam. If wasn't meant to, go back and try again" )
                           return true
                       end
                   else
                       # If the key does not verify, post the comment
                       # but note the failure in the apache error logs.
                       $stderr.puts( "Hobix: Akismet API key did not verify." )
                   end
               end
                   
               # Save the comment, upgen
               @weblog.storage.append_to_attachment( entry_id, 'comments', comment )
               @weblog.regenerate :update
               
               # Redirect
                link = @weblog.output_entry_map[entry_id]
                app.setup_redirection( 302, @weblog.expand_path( link[:page].link ) )
                return true
            when "preview"
                app.puts RedCloth.new( app._POST[Comments.form_field('content')] ).to_html
                return true
            end
        end
    end
end

end
end
