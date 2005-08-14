#
# = hobix/api.rb
#
# Hobix API, used by any external service (DRb or REST, etc.)
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
module Hobix

# The API facet
class API < BaseFacet

    def initialize( weblog, defaults = {} )
        @weblog = weblog
    end
    def get app
        if app.respond_to? :action_uri
            return true unless protect app, @weblog
            @app = app
            prefix, action, *args = app.action_uri.split( '/' )
            if prefix == "remote"
                if respond_to? "#{ action }_action"
                    begin
                        @app.puts method( "#{ action }_action" ).call( *args ).to_yaml
                        return true
                    rescue StandardError => e
                        @app.puts e.to_yaml
                    end
                    return true
                end
            end
        end
    end

    def upgen_action
        @weblog.regenerate( :update )
        "Regeneration complete"
    end

    def regen_action
        @weblog.regenerate
        "Regeneration complete"
    end

    def new_action
        @weblog.entry_class.new
    end

    def list_action( *inpath )
        inpath = inpath.join '/'
        @weblog.storage.find( :all => true, :inpath => inpath )
    end

    def search_action( words, *inpath )
        inpath = inpath.join '/'
        @weblog.storage.find( :all => true, :inpath => inpath, :search => words.split( ',' ) )
    end

    def post_action( *id )
        id = id.join '/'
        case @app.request_method
        when "GET"
            @weblog.storage.load_entry id
        when "POST"
            entry = YAML::load( @app.request_body )
            @weblog.storage.save_entry id, entry
            "Entry successfully saved."
        end
    end

    def edit_action
        case @app.request_method
        when "GET"
            @weblog
        when "POST"
            config = YAML::load( @app.request_body )
            config.save @weblog.hobix_yaml
            "Weblog configuration saved."
        end
    end
end

end
