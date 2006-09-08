#
# = hobix/trackbacks.rb
#
# Hobix command-line weblog system, API for trackbacks.
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

require 'hobix/facets/trackbacks'
require 'time'
require 'rexml/document'

module Hobix
module Out
class Quick
  prepend_def :entry_title_erb, %{
    <+ entry_trackback_rdf +>
  }

  def entry_trackback_rdf_erb; %{
    <!--
    <%= trackback_rdf_for( weblog, entry ) %>
    -->
  } end

  append_def :entry_erb, %{
    <% if entry and not defined? entries %><+ entry_trackback +><% end %>
  }

  def entry_trackback_erb; %{
    <a name="trackbacks"></a>
    <div id="trackbacks">
    <% entry_id = entry.id %>
    <% trackbacks = weblog.storage.load_attached( entry_id, "trackbacks") rescue [] %>
    <% trackbacks.each do |trackback| %>
    <div class="entry">
        <div class="entryAttrib">
            <div class="entryAuthor"><h3><%= trackback.blog_name %></h3></div>
            <div class="entryTime">tracked back on <%= trackback.created.strftime("<nobr>%d %b %Y</nobr> at <nobr>%H:%M</nobr>" ) %></div>
        </div>
        <div class="entryContentOuter"><div class="entryContent">
            <h3><a href="<%= trackback.url %>"><%= trackback.title %></a></h3>
            <%= trackback.excerpt %>
        </div></div>
    </div>
    <% end %>
    </div>
  } end

  private
  def trackback_rdf_for( weblog, entry )
    trackback_link = '%s/control/trackback/%s' % [weblog.link, entry.id]
    doc = REXML::Document.new
    rdf = doc.add_element( "rdf:RDF" )
    rdf.add_namespace( "rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#" )
    rdf.add_namespace( "trackback", "http://madskills.com/public/xml/rss/module/trackback/" )
    rdf.add_namespace( "dc", "http://purl.org/dc/elements/1.1/" )
    desc = rdf.add_element( "rdf:Description" )
    desc.add_attribute( "rdf:about", "")
    desc.add_attribute( "trackback:ping", trackback_link )
    desc.add_attribute( "dc:title", entry.title )
    desc.add_attribute( "dc:identifier", entry.link )
##  i've dropped the following fields because i don't think they're used, and
##  dc:description in particular will potentially double the size of the 
##  html pages. if they're actually useful to anyone, please re-add.
##
##  desc.add_attribute( "dc:description", ( entry.summary || entry.content ).to_html )
##  desc.add_attribute( "dc:creator", entry.author )
##  desc.add_attribute( "dc:date", entry.created.xmlschema )
    doc.to_s
  end
end
end

class Trackback < BaseContent
  _! "Trackback Information"
  _ :blog_name, :edit_as => :text, :req => true
  _ :url, :edit_as => :text, :req => true
  _ :title, :edit_as => :text, :req => true
  _ :excerpt , :edit_as => :text, :req => true
  _ :created, :edit_as => :datetime
  _ :ipaddress, :edit_as => :text

  yaml_type "tag:hobix.com,2005:trackback"
end
end
