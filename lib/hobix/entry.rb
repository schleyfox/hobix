#
# = hobix/entry.rb
#
# Hobix command-line weblog system.
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
require 'redcloth'
require 'yaml'

module Hobix
class Entry
    attr_accessor :id, :link, :title, :tagline, :summary, :author,
                  :contributor, :modified, :issued, :created,
                  :summary, :body

    def to_yaml_type
        "!hobix.com,2004/entry"
    end

    # Load the weblog entry from a file.
    def Entry::load( file )
        YAML::load( File::open( file ) )
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'entry' ) do |type, val|
    val['body'] = RedCloth.new( val['body'].to_s )
    YAML::object_maker( Hobix::Entry, val )
end
