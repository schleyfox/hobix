#
# = hobix/out/rss.rb
#
# RSS 2.0 output for Hobix.
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

module Hobix
module Out
class RSS < Hobix::BaseOutput
    def initialize( weblog )
        @path = weblog.skel_path
    end
    def extension
        "rss"
    end
    def load( file_name, vars )
        rssdoc = REXML::Document.new( <<EOXML )
<rss version="2.0" 
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
  xmlns:admin="http://webns.net/mvcb/"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <channel>
    <title></title>
    <link></link>
    <description></description>
    <dc:language>en-us</dc:language>
    <dc:creator></dc:creator>
    <dc:date></dc:date>
    <admin:generatorAgent rdf:resource="http://hobix.com/?v=#{ Hobix::VERSION }" />
    <sy:updatePeriod>hourly</sy:updatePeriod>
    <sy:updateFrequency>1</sy:updateFrequency>
    <sy:updateBase>2000-01-01T12:00+00:00</sy:updateBase>
    </channel>
</rss>
EOXML
        rssdoc << REXML::XMLDecl.new
        rssdoc.elements['/rss/channel/title'].text = vars[:weblog].title
        rssdoc.elements['/rss/channel/link'].text = vars[:weblog].link.to_s
        rssdoc.elements['/rss/channel/description'].text = vars[:weblog].tagline
        rssdoc.elements['/rss/channel/dc:date'].text = Time.now.utc.strftime( "%Y-%m-%dT%H:%M:%S+00:00" )
        ( vars[:entries] || [vars[:entry]] ).each do |e|
            ele = REXML::Element.new 'item'
            ele_title = REXML::Element.new 'title'
            ele_title.text = e.title
            ele << ele_title
            ele_link = REXML::Element.new 'link'
            ele_link.text = "#{ e.link }"
            ele << ele_link
            ele_guid = REXML::Element.new 'guid'
            ele_guid.attributes['isPermaLink'] = 'false'
            ele_guid.text = "#{ e.id }@#{ vars[:weblog].link }"
            ele << ele_guid
            ele_subject = REXML::Element.new 'dc:subject'
            ele_subject.text = e.section_id
            ele << ele_subject
            e.keywords.each do |kw|
                ele_subject = REXML::Element.new 'dc:subject'
                ele_subject.text = kw
                ele << ele_subject
            end
            ele_creator = REXML::Element.new 'dc:creator'
            ele_creator.text = vars[:weblog].authors[e.author]['name']
            ele << ele_creator
            ele_pubDate = REXML::Element.new 'dc:date'
            ele_pubDate.text = ( e.modified || e.created ).dup.utc.strftime( "%Y-%m-%dT%H:%M:%S+00:00" )
            ele << ele_pubDate
            ele_desc = REXML::Element.new 'description'
            ele_desc.text = e.content.to_html.gsub( /(src|href)="\//, "\\1=\"#{ vars[:weblog].link.rooturi }/" )
            ele << ele_desc
            rssdoc.elements['/rss/channel'].add ele
        end
        rssdoc.to_s
    end
end
end
end
