#
# = hobix/bixwik.rb
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
require 'hobix/weblog'

module Hobix
# The BixWik class is an extended Weblog, which acts like a Wiki.
# (See http://instiki.org/ for inspiration.)
class BixWikPlugin < Hobix::BasePlugin
    def initialize( weblog )
        class << weblog
            include Hobix::BixWik
        end
    end
end

module BixWik

    QUICK_MENU = YAML::load <<-END
        --- %YAML:1.0 !omap
        - HomePage: [Home Page, H, Start Over]
        - list/index: [All Pages, A, Alphabetically sorted list of pages]
        - recent/index: [Recently Revised, U, Pages sorted by when they were last changed]
        - authors/index: [Authors, ~, Who wrote what]
        - FeedList: [Feed List, ~, Subscribe to changes by RSS]
    END

    def default_entry_class; "Hobix::BixWik::Entry"; end
    def default_index_class; "Hobix::BixWik::IndexEntry"; end

    # Handler for templates with `index' prefix.  These pages simply
    # mirror the `HomePage' entry.
    def skel_index( path_storage )
        homePage = path_storage.match( /^HomePage$/ ).first
        page = Page.new( '/index' )
        unless homePage
            homePage = Hobix::Storage::IndexEntry.new( path_storage.default_entry( authors.keys.first ) )
        end
        page.timestamp = homePage.created
        page.updated = homePage.created
        yield :page => page, :entry => homePage
    end

    # Handler for templates with `list/index' prefix.  These templates will
    # receive IndexEntry objects for every entry in the system.  Only one
    # index page is requested by this handler.
    def skel_recent_index( path_storage )
        index_entries = storage.find( :all => true )
        page = Page.new( '/list/index' )
        page.timestamp = index_entries.first.created
        page.updated = storage.last_updated( index_entries )
        yield :page => page, :entries => index_entries
    end

    # Handler for templates with `recent/index' prefix.  These templates will
    # receive entries loaded by +Hobix::BaseStorage#lastn+.  Only one
    # index page is requested by this handler.
    def skel_recent_index( path_storage )
        index_entries = storage.lastn( @lastn || 120 )
        page = Page.new( '/recent/index' )
        page.timestamp = index_entries.first.created
        page.updated = storage.last_updated( index_entries )
        yield :page => page, :entries => index_entries
    end

    # Handler for templates with `list/index' prefix.  These templates will
    # receive a list of all pages in the Wiki.
    def skel_list_index( path_storage )
        all_pages = storage.all
        page = Page.new( '/list/index' )
        page.timestamp = all_pages.first.created
        page.updated = storage.last_updated( all_pages )
        yield :page => page, :entries => all_pages, :no_load => true
    end

    def abs_link( word )
        output_entry_map[word] && output_entry_map[word][:page].link
    end

    def wiki_page( src )
        src.gsub( /\b([A-Z][a-z]+[A-Z][\w\/]+)\b/ ) { wiki_link( $1 ) }
    end

    def wiki_link( word )
        abs_link = output_entry_map[word]
        if abs_link
            "<a class=\"existingWikiWord\" href=\"#{ expand_path( abs_link[:page].link ) }\">#{ Hobix::BixWik::wiki_word word }</a>"
        else
            "<span class=\"newWikiWord\">#{ Hobix::BixWik::wiki_word word }<a href=\"#{ expand_path( "control/edit/#{ word }" ) }\">?</a></span>"
        end
    end

    def self.wiki_word( id )
        Hobix::BixWik::QUICK_MENU[ id ].to_a.first || id.gsub( /^\w|_\w|[A-Z]/ ) { |up| " #{up[-1, 1].upcase}" }.strip
    end

    require 'redcloth'
    class WikiRedCloth < RedCloth
    end

    class IndexEntry < Hobix::IndexEntry
        _ :author
        def title
            Hobix::BixWik::wiki_word( self.id )
        end
        def to_yaml_type
            "!hobix.com,2004/bixwik/indexEntry"
        end
    end

    class Entry < Hobix::Entry
        def title
            Hobix::BixWik::wiki_word( self.id )
        end
        def to_yaml_type
            "!hobix.com,2004/bixwik/entry"
        end
        def self.text_processor; WikiRedCloth; end
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'bixwik/entry' ) do |type, val|
    Hobix::BixWik::Entry::maker( val )
end

YAML::add_domain_type( 'hobix.com,2004', 'bixwik/indexEntry' ) do |type, val|
    YAML::object_maker( Hobix::BixWik::IndexEntry, val )
end

module Hobix
module Facets
class WikiEdit < BaseFacet
    def initialize( weblog, defaults = {} )
        @weblog = weblog
    end
    def get app
        if app.respond_to? :action_uri
            ns, method_id = app.action_uri.split( '/', 2 )
            return false unless ns == "edit"

            # Display publisher page
            app.content_type = 'text/html'
            app.puts ::ERB.new( erb_src, nil, nil, "_bixwik" ).result( binding )
            return true
        end
    end
end
end

module Out
class Quick
def banner_erb; %{
  <% page_id = page.id %>
  <% page_id = 'HomePage' if page.id == 'index' %>
  <% page_name = Hobix::BixWik::wiki_word( page_id ) %>
  <div id="banner">
    <% if page_id == "HomePage" %>
      <h1 id="title"><%= weblog.title %></h1>
      <% if weblog.tagline %><div id="tagline"><%= weblog.tagline %></div><% end %>
    <% else %>
      <div id="title"><%= weblog.title %></div>
      <h1 id="pageName"><%= page_name %></h1>
    <% end %>
    <form id="navigationForm" class="navigation" action="<%= weblog.expand_path( 'search' ) %>" action="get" style="font-size: 10px">  
    <% Hobix::BixWik::QUICK_MENU.each do |menu_link, attr| %>
      <% if page_id == menu_link %>
        <%= attr[0] %>
      <% else %>
      <a href="<%= weblog.abs_link( menu_link ) %>" title="<% if attr[1] %>[<%= attr[1] %>] <% end %><%= attr[2] %>" 
           accesskey="<%= attr[1] %>"><%= attr[0] %></a>
      <% end %> |
    <% end %>
    <input type="text" id="searchField" name="query" style="font-size: 10px" value="Search" onClick="this.value == 'Search' ? this.value = '' : true">
    </form>
  </div> }
end
def entry_title_erb; end
def entry_content_erb
    %{ <div class="entryContent"><%= weblog.wiki_page( entry.content.to_html ) %></div> }
end
def sidebar_erb; nil; end
def entry_footer_erb; %{
  Revision from <%= ( entry.modified || entry.created ).strftime( "%B %d, %Y %H:%M" ) %> by <%= weblog.wiki_link( "authors/" + entry.author ) %> }
end
end
end
end
