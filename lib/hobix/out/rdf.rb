#
# = hobix/out/rdf.rb
#
# RSS (RDF Site Summary) 1.0 output for Hobix.
#
# Copyright (c) 2004 Giulio Piancastelli
#
# Written & maintained by Giulio Piancastelli <gpian@softhome.net>
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
require 'hobix/base'
require 'rexml/document'

module Hobix
module Out
class RDF < Hobix::BaseOutput
    def initialize(weblog)
        @path = weblog.skel_path
    end
    def extension
        "rdf"
    end
    def load(file_name, vars)
        rdfdoc = REXML::Document.new(<<EOXML)
<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
  xmlns:admin="http://webns.net/mvcb/"
  xmlns:cc="http://web.resource.org/cc/"
  xmlns="http://purl.org/rss/1.0/">
    <channel>
    <title></title>
    <link></link>
    <description></description>
    <dc:language>en-us</dc:language>
    <!--<dc:creator></dc:creator>-->
    <dc:date></dc:date>
    <admin:generatorAgent rdf:resource="http://hobix.com/?v=#{ Hobix::VERSION }" />
    <sy:updatePeriod>hourly</sy:updatePeriod>
    <sy:updateFrequency>1</sy:updateFrequency>
    <sy:updateBase>2000-01-01T12:00+00:00</sy:updateBase>
    
    <items>
        <rdf:Seq></rdf:Seq>
    </items>
    
    </channel>
</rdf:RDF>
EOXML
        rdfdoc << REXML::XMLDecl.new
        rdfdoc.elements['/rdf:RDF/channel/'].attributes['rdf:about'] = vars[:weblog].link
        rdfdoc.elements['/rdf:RDF/channel/title'].text = vars[:weblog].title
        rdfdoc.elements['/rdf:RDF/channel/link'].text = vars[:weblog].link
        rdfdoc.elements['/rdf:RDF/channel/description'].text = vars[:weblog].tagline
        rdfdoc.elements['/rdf:RDF/channel/dc:date'].text = Time.now.utc.strftime( "%Y-%m-%dT%H:%M:%S+00:00" )
        (vars[:entries] || [vars[:entry]]).each do |e|
            ele = REXML::Element.new 'item'
            ele.attributes['rdf:about'] = "#{e.link}"
            if e.title
              ele_title = REXML::Element.new 'title'
              ele_title.text = e.title
              ele << ele_title
            end
            ele_link = REXML::Element.new 'link'
            ele_link.text = "#{e.link}"
            ele << ele_link
            ele_subject = REXML::Element.new 'dc:subject'
            ele_subject.text = e.section_id
            ele << ele_subject
            ele_creator = REXML::Element.new 'dc:creator'
            ele_creator.text = vars[:weblog].authors[e.author]['name']
            ele << ele_creator
            ele_pubDate = REXML::Element.new 'dc:date'
            ele_pubDate.text = e.created.dup.utc.strftime( "%Y-%m-%dT%H:%M:%S+00:00" )
            ele << ele_pubDate
            ele_desc = REXML::Element.new 'description'
            if !e.summary
              ele_desc.text = e.content.to_html.gsub(/img src="\//, "img src=\"#{vars[:weblog].link}")
            else
              ele_desc.text = e.summary
            end
            ele << ele_desc
            rdfdoc.elements['/rdf:RDF'].add ele
            # also add an element to the <rdf:Seq> sequence in <items>
            li = REXML::Element.new 'rdf:li'
            li.attributes['rdf:resource'] = "#{e.link}"
            rdfdoc.elements['/rdf:RDF/channel/items/rdf:Seq'] << li
        end
        rdfdoc.to_s
    end
end
end
end
