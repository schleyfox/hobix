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
module APIMethods
    # Update the site
    def upgen_action_explain; "Update site with only the latest changes."; end
    def upgen_action_args; ['weblog-name']; end
    def upgen_action( weblog )
        weblog.regenerate( :update )
    end

    # Regenerate the site
    def regen_action_explain; "Regenerate the all the pages throughout the site."; end
    def regen_action_args; ['weblog-name']; end
    def regen_action( weblog )
        weblog.regenerate
    end

    # Edit a weblog from local config
    def edit_action_explain; "Edit weblog's configuration"; end
    def edit_action_args; ['weblog-name']; end
    def edit_action( weblog )
        path = weblog.hobix_yaml
        weblog = aorta( weblog )
        return if weblog.nil?
        weblog.save( path )
    end

end

class API
    include APIMethods
    def initialize( weblogs )
        @weblogs = weblogs
    end

    def call( cmd, *opts )
        if cmdline.respond_to? "#{ cmd }_weblog"
            mname = "#{ cmd }_weblog"
        elsif cmdline.respond_to? "#{ cmd }_action"
            weblog = opts.shift
            unless @weblogs.has_key? weblog
                raise ArgumentError, "no weblog `#{ weblog }' found."
            end
            hobix_weblog = Hobix::Weblog.load( @weblogs[ weblog ] )
            opts.unshift hobix_weblog
            mname = "#{ cmd }_action"
        end
        unless mname
            raise ArgumentError, "no hobix command `#{ cmd }'. use `hobix' without arguments to get help."
        end
        m = cmdline.method( mname )
        begin
            m.call( *opts )
        rescue ArgumentError => ae
            arglist = [cmd] + cmdline.method( "#{ mname }_args" ).call
            raise ArgumentError, "use syntax: `hobix #{ arglist.join( ' ' ) }'"
        end
    end
end

end
