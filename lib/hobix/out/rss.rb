#
# = hobix/out/rss.rb
#
# RSS 2.0 output for Hobix.
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
<rss version="2.0">
    <channel>
    <title></title>
    <link></link>
    <description></description>
    <language>en-us</language>
    </channel>
</rss>
EOXML
        rssdoc << REXML::XMLDecl.new
        rssdoc.elements['/rss/channel/title'].text = vars[:weblog].title
        rssdoc.elements['/rss/channel/link'].text = vars[:weblog].link
        rssdoc.elements['/rss/channel/description'].text = vars[:weblog].tagline
        vars[:entries].each do |e|
            ele = REXML::Element.new 'item'
            ele_title = REXML::Element.new 'title'
            ele_title.text = e.title
            ele << ele_title
            ele_guid = REXML::Element.new 'link'
            ele_guid.text = "#{ e.link }"
            ele << ele_guid
            ele_guid = REXML::Element.new 'guid'
            ele_guid.text = "#{ vars[:weblog].link }#{ e.created.strftime( "%Y/%m/%d/" ) }#{ e.created.to_i }"
            ele << ele_guid
            ele_desc = REXML::Element.new 'description'
            ele_desc.text = e.content.to_html.gsub( /img src="\//, "img src=\"#{ vars[:weblog].link }" )
            ele << ele_desc
            rssdoc.elements['/rss/channel'].add ele
        end
        rssdoc.to_s
    end
end
end
end
