#
# = hobix/out/erb.rb
#
# Hobix processing of ERB templates.
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
require 'erb'

module Hobix
module Out
class ERBError < StandardError; end
class ERB < Hobix::BaseOutput
    def initialize( weblog )
        @path = weblog.skel_path
    end
    def extension
        "erb"
    end
    def load( file_name, vars )
        @bind = binding
        vars.each do |k, v|
            eval( "#{ k } = vars[#{ k.inspect }]", @bind )
        end
        @relpath = File.dirname( file_name )
        load_erb = import_erb( file_name )
        begin
            load_erb.result( @bind )
        rescue Exception => e
            raise ERBError, "Error `#{ e.message }' in erb #{ file_name }."
        end
    end
    def import( fname )
        fname = if fname =~ /^\//
                    File.join( @path, fname )
                else
                    File.join( @relpath, fname )
                end
        import_erb( fname ).result( @bind )
    end
    def import_erb(fname)
        File.open(fname) { |fp| ::ERB.new(fp.read, nil, nil, "_hobixout#{ rand( 9999999 ) }" ) }
    end
end
end
end
