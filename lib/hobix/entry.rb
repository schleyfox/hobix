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
                  :contributors, :modified, :issued, :created,
                  :content

    def to_yaml_properties
        [
            ['@title', :req], 
            ['@author', :req], 
            ['@contributors', :opt], 
            ['@created', :opt], 
            ['@tagline', :opt], 
            ['@summary', :opt], 
            ['@content', :req]
        ].
        reject do |prop, req|
            req == :opt and not instance_variable_get( prop )
        end.
        collect do |prop, req|
            prop
        end
    end

    def to_yaml_type
        "!okay/news/entry#1.0"
    end

    # Load the weblog entry from a file.
    def Entry::load( file )
        YAML::load( File::open( file ) )
    end
end
end

YAML::add_domain_type( 'okay.yaml.org,2002', 'news/entry#1.0' ) do |type, val|
    ['content', 'tagline', 'summary'].each do |f|
        val[f] = RedCloth.new( val[f].to_s ) if val[f]
    end
    YAML::object_maker( Hobix::Entry, val )
end
YAML::add_domain_type( 'hobix.com,2004', 'entry' ) do |type, val|
    val['content'] = RedCloth.new( val['body'].to_s )
    YAML::object_maker( Hobix::Entry, val )
end
