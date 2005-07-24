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
    def self.comment_class; Hobix::Entry end

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
                end
                comments = @weblog.storage.load_attached( entry_id, 'comments' ) rescue []
                comments << comment

                # Save the attachment, upgen
                @weblog.storage.save_attached( entry_id, "comments", comments )
                @weblog.regenerate :update

                # Redirect
                link = @weblog.output_entry_map[entry_id]
                app.setup_redirection( 302, link[:page].link )
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
