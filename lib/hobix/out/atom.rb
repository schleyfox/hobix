#
# = hobix/out/atom.rb
#
# Atom output for Hobix.
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
require 'rexml/document'
require 'uri'

module Hobix
module Out
class Atom < Hobix::BaseOutput
    def initialize( weblog )
        @path = weblog.skel_path
    end
    def extension
        "atom"
    end
    def load( file_name, vars )
        rssdoc = REXML::Document.new( <<EOXML )
<feed version="0.3" xmlns="http://purl.org/atom/ns#" xmlns:dc="http://purl.org/dc/elements/1.1/" xml:lang="en">
<title></title>
<link rel="alternate" type="text/html" href="" />
<modified></modified>
<tagline></tagline>
<id></id>
<generator url="http://hobix.com/" version="#{ Hobix::VERSION }">Hobix</generator>
<copyright></copyright>
EOXML
        uri = URI::parse( vars[:weblog].link )
        rssdoc << REXML::XMLDecl.new
        rssdoc.elements['/feed/title'].text = vars[:weblog].title
        rssdoc.elements['/feed/link'].attributes['href'] = vars[:weblog].link
        rssdoc.elements['/feed/tagline'].text = vars[:weblog].tagline
        rssdoc.elements['/feed/modified'].text = vars[:page].updated.strftime( "%Y-%m-%dT%H:%M:%SZ" )
        rssdoc.elements['/feed/id'].text = "tag:#{ uri.host },#{ Time.now.year }:blog#{ uri.path }"
        rssdoc.elements['/feed/copyright'].text = vars[:weblog].copyright || "None"
        vars[:entries].each do |e|
            ele = REXML::Element.new 'entry'
            ele_title = REXML::Element.new 'title'
            ele_title.text = e.title
            ele << ele_title
            ele_link = REXML::Element.new 'link'
            ele_link.attributes['rel'] = 'alternate'
            ele_link.attributes['type'] = 'text/html'
            ele_link.attributes['href'] = e.link
            ele << ele_link
            ele_guid = REXML::Element.new 'id'
            ele_guid.text = "tag:#{ uri.host },#{ Time.now.year }:blog#{ uri.path }entry/#{ e.id }"
            ele << ele_guid
            ele_time = REXML::Element.new 'issued'
            ele_time.text = e.created.strftime( "%Y-%m-%dT%H:%M:%SZ" )
            ele << ele_time
            ele_time = REXML::Element.new 'modified'
            ele_time.text = e.modified.strftime( "%Y-%m-%dT%H:%M:%SZ" )
            ele << ele_time
            if e.summary
                ele_summ = REXML::Element.new 'summary'
                ele_summ.attributes['type'] = 'text/html'
                ele_summ.attributes['mode'] = 'escaped'
                ele_summ.text = e.summary.to_html.gsub( /img src="\//, "img src=\"#{ vars[:weblog].link }" )
                ele << ele_summ
            end
            author = vars[:weblog].authors[e.author]
            ele_auth = REXML::Element.new 'author'
            ele_name = REXML::Element.new 'name'
            ele_name.text = author['name']
            ele_auth << ele_name
            ele << ele_auth
            ele_desc = REXML::Element.new 'content'
            ele_desc.attributes['type'] = 'text/html'
            ele_desc.attributes['mode'] = 'escaped'
            ele_desc.text = e.content.to_html.gsub( /img src="\//, "img src=\"#{ vars[:weblog].link }" )
            ele << ele_desc
            rssdoc.elements['/feed'].add ele
        end
        rssdoc.to_s
    end
end
end
end
# <entry>
# <title><$MTEntryTitle remove_html="1" encode_xml="1"$></title>
# <link rel="alternate" type="text/html" href="<$MTEntryPermalink encode_xml="1"$>" />
# <modified><$MTEntryModifiedDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></modified>
# <issued><$MTEntryDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></issued>
# <id>tag:<$MTBlogHost exclude_port="1" encode_xml="1"$>,<$MTEntryDate format="%Y">:<$MTBlogRelativeURL encode_xml="1"$>/<$MTBlogID$>.<$MTEntryID$></id>
# <created><$MTEntryDate utc="1" format="%Y-%m-%dT%H:%M:%SZ"$></created>
# <summary type="text/plain"><$MTEntryExcerpt remove_html="1" encode_xml="1"$></summary>
# <author>
# <name><$MTEntryAuthor encode_xml="1"$></name>
# <MTIfNonEmpty tag="MTEntryAuthorURL"><url><$MTEntryAuthorURL encode_xml="1"$></url></MTIfNonEmpty>
# <MTIfNonEmpty tag="MTEntryAuthorEmail"><email><$MTEntryAuthorEmail encode_xml="1"$></email></MTIfNonEmpty>
# </author>
# <MTIfNonEmpty tag="MTEntryCategory"><dc:subject><$MTEntryCategory encode_xml="1"$></dc:subject></MTIfNonEmpty>
# <content type="text/html" mode="escaped" xml:lang="en" xml:base="<$MTBlogURL encode_xml="1"$>">
# <$MTEntryBody encode_xml="1"$>
# <$MTEntryMore encode_xml="1"$>
# </content>
# </entry>
# </MTEntries>
# </feed>

