#
# = hobix/out/atom.rb
#
# Atom output for Hobix.
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
require 'hobix/base'
require 'rexml/document'
require 'uri'

module Hobix
module Out
module XmlQuick
    def x( title, txt, attrs = nil )
        e = REXML::Element.new title
        e.text = txt if txt
        attrs.each { |a,b| e.attributes[a] = b } if attrs
        self << e
    end
end
class Atom < Hobix::BaseOutput
    def initialize( weblog )
        @path = weblog.skel_path
    end
    def extension
        "atom"
    end
    def load( file_name, vars )
        rssdoc = REXML::Document.new( <<EOXML )
<feed version="0.3"
  xmlns="http://purl.org/atom/ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xml:lang="en">
    <title></title>
    <link rel="alternate" type="text/html" href="" />
    <modified></modified>
    <tagline></tagline>
    <id></id>
    <generator url="http://hobix.com/" version="#{ Hobix::VERSION }">Hobix</generator>
    <copyright></copyright>
</feed>
EOXML
        uri = vars[:weblog].link
        rssdoc << REXML::XMLDecl.new
        rssdoc.elements['/feed/title'].text = vars[:weblog].title
        rssdoc.elements['/feed/link'].attributes['href'] = vars[:weblog].link.to_s
        rssdoc.elements['/feed/tagline'].text = vars[:weblog].tagline
        rssdoc.elements['/feed/modified'].text = vars[:page].updated.strftime( "%Y-%m-%dT%H:%M:%SZ" )
        rssdoc.elements['/feed/id'].text = "tag:#{ uri.host },#{ Time.now.year }:blog#{ uri.path }"
        rssdoc.elements['/feed/copyright'].text = vars[:weblog].copyright || "None"
        ( vars[:entries] || [vars[:entry]] ).each do |e|
            ele = REXML::Element.new 'entry'
            ele.extend XmlQuick
            ele.x( 'title', e.title )
            ele.x( 'link', nil, {'rel' => 'alternate', 'type' => 'text/html', 'href' => e.link } )
            ele.x( 'id', "tag:#{ uri.host },#{ Time.now.year }:blog#{ uri.path }entry/#{ e.id }" )
            ele.x( 'issued', e.created.strftime( "%Y-%m-%dT%H:%M:%SZ" ) )
            ele.x( 'modified', e.modified.strftime( "%Y-%m-%dT%H:%M:%SZ" ) )
            ele.x( 'dc:subject', e.section_id )
            e.keywords.each do |kw|
                ele.x( 'dc:subject', kw )
            end
            ele.x( 'summary', 
                e.summary.to_html.gsub( /img src="\//, "img src=\"#{ vars[:weblog].link }/" ),
                {'type' => 'text/html', 'mode' => 'escaped'} ) if e.summary
            author = vars[:weblog].authors[e.author]
            ele_auth = REXML::Element.new 'author'
            ele_auth.extend XmlQuick
            ele_auth.x( 'name', author['name'] )
            ele_auth.x( 'url', author['url'] ) if author['url']
            ele_auth.x( 'email', author['email'] ) if author['email']
            ele << ele_auth
            ele.x( 'content',
                e.content.to_html.gsub( /img src="\//, "img src=\"#{ vars[:weblog].link }/" ),
                {'type' => 'text/html', 'mode' => 'escaped'} )
            rssdoc.elements['/feed'].add ele
        end
        rssdoc.to_s
    end
end
end
end
