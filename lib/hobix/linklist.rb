#
# = hobix/linklist.rb
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
require 'hobix/entry'
require 'redcloth'
require 'yaml'

module Hobix
class LinkList < Entry
    attr_accessor :id, :link, :title, :tagline, :summary, :author,
                  :contributors, :modified, :issued, :created, :links

    def to_yaml_properties
        [
            ['@title', :opt], 
            ['@author', :req], 
            ['@contributors', :opt], 
            ['@created', :opt], 
            ['@tagline', :opt], 
            ['@summary', :opt], 
            ['@links', :req]
        ].
        reject do |prop, req|
            req == :opt and not instance_variable_get( prop )
        end.
        collect do |prop, req|
            prop
        end
    end

    def content
        RedCloth.new( 
            @links.collect do |title, url|
                "\"#{ title }\":#{ url }"
            end.join( "\n\n" )
        )
    end

    def to_yaml_type
        "!hobix.com,2004/linklist"
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'linklist' ) do |type, val|
    ['tagline', 'summary'].each do |f|
        val[f] = RedCloth.new( val[f].to_s ) if val[f]
    end
    val['links'] = YAML::transfer( 'omap', val['links'] )
    YAML::object_maker( Hobix::LinkList, val )
end
