#
# = hobix/linklist.rb
#
# Hobix command-line weblog system.
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
require 'redcloth'
require 'yaml'

# The LinkList class is an entry type for storing links.  It's
# also a good example of how to subclass the Entry class so you
# can store your own kinds of entries.
#
# == Properties
#
# The LinkList responds to many of the same properties listed
# in the +Hobix::Entry+ class.  The primary difference is that,
# instead of having a +content+ property, there is a +links+
# property.
#
# links::   Internally, this class stores a +YAML::Omap+, an
#           Array of pairs.  The links are kept in the order
#           shown in the YAML file.  They consist of a link
#           title, paired with a URL.
#
# == Sample LinkList
#
#    --- %YAML:1.0 !hobix.com,2004/linklist
#    title: Hobix Links
#    author: why
#    created: 2004-05-30 18:53:00 -06:00
#    links:
#    - Hobix: http://hobix.com/
#    - Learn Hobix: http://hobix.com/learn/
#    - Textile Reference: http://hobix.com/textile/
#
module Hobix
class LinkList < Entry
    attr_accessor :id, :link, :title, :tagline, :summary, :author,
                  :contributors, :modified, :issued, :created, :links

    # Definition map for outputting YAML.  Used by +to_yaml+,
    # see +ToYamlExtras+ module.
    def property_map
        [
            ['@title', :opt, :text], 
            ['@author', :opt, :text], 
            ['@contributors', :opt, :textarea], 
            ['@created', :opt, :text], 
            ['@tagline', :opt, :text], 
            ['@summary', :opt, :textarea], 
            ['@links', :req, :textarea]
        ]
    end

    # Converts the link list into a RedCloth string for display
    # in templates.
    def content
        RedCloth.new( 
            @links.collect do |title, url|
                "* \"#{ title }\":#{ url }"
            end.join( "\n" )
        )
    end

    # LinkLists currently output as YAML type family
    # !hobix.com,2004/linklist.
    def to_yaml_type
        "!hobix.com,2004/linklist"
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'linklist' ) do |type, val|
    ['tagline', 'summary'].each do |f|
        val[f] = RedCloth.new( val[f].to_s ) if val[f]
    end
    if val['links'].is_a? ::Array
        val['links'] = YAML::transfer( 'omap', val['links'] )
    end
    YAML::object_maker( Hobix::LinkList, val )
end
