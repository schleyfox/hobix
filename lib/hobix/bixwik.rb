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
class BixWik < Weblog

    def to_yaml_type
        "!hobix.com,2004/bixwik"
    end

    alias _start start
    def start( hobix_yaml )
        @requires.collect! do |req|
            opts = nil
            unless req.respond_to? :to_str
                req, opts = req.to_a.first
            end
            if req == 'hobix/out/quick'
                opts ||= {}
                opts = QUICK_MASTER.merge( opts )
            end
            {req => opts}
        end
        _start( hobix_yaml )
    end

    # Handler for templates with `index' prefix.  These pages simply
    # mirror the `HomePage' entry.
    def skel_index( path_storage )
        homePage = path_storage.match( /^HomePage$/ ).first
        page = Page.new( '/index' )
        if homePage
            page.timestamp = homePage[1]
            page.updated = homePage[1]
        end
        yield :page => page, :entry => homePage
    end

    # Handler for templates with `recent/index' prefix.  These templates will
    # receive entries loaded by +Hobix::BaseStorage#lastn+.  Only one
    # index page is requested by this handler.
    def skel_recent_index( path_storage )
        index_entries = storage.lastn( @lastn || 120 )
        page = Page.new( '/recent/index' )
        page.timestamp = index_entries.first[1]
        page.updated = storage.last_modified( index_entries )
        yield :page => page, :entries => index_entries
    end

    # Handler for templates with `list/index' prefix.  These templates will
    # receive a list of all pages in the Wiki.
    def skel_list_index( path_storage )
        all_pages = storage.all
        page = Page.new( '/list/index' )
        page.timestamp = all_pages.first[1]
        page.updated = storage.last_modified( all_pages )
        yield :page => page, :entries => all_pages 
    end

    def wiki_word( word )
        Hobix::BixWik::QUICK_MENU[ word ].to_a[0] || word.gsub( /^\w|_\w|[A-Z]/ ) { |up| " #{up[-1, 1].upcase}" }
    end

    def wiki_link( word )
        "<a href=\"#{ expand_path( word ) }\">#{ word }</a>"
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'bixwik' ) do |type, val|
    YAML::object_maker( Hobix::BixWik, val )
end

Hobix::BixWik::QUICK_MENU = YAML::load <<END
--- %YAML:1.0 !omap
- HomePage: [Home Page, H, Start Over]
- list/index: [All Pages, A, Alphabetically sorted list of pages]
- recent/index: [Recently Revised, U, Pages sorted by when they were last changed]
- authors/index: [Authors, ~, Who wrote what]
- FeedList: [Feed List, ~, Subscribe to changes by RSS]
END

Hobix::BixWik::QUICK_MASTER = YAML::load <<END
--- %YAML:1.0
banner: |
  <div id="banner">
    <% if page.link == "HomePage" %>
      <h1 id="title"><%= weblog.title %></h1>
    <% else %>
      <div id="title"><%= weblog.title %></div>
      <h1 id="pageName"><%= weblog.wiki_word( page.link ) %></h1>
    <% end %>
    <form id="navigationForm" class="navigation" action="<%= weblog.expand_path( 'search' ) %>" action="get" style="font-size: 10px">  
    <% Hobix::BixWik::QUICK_MENU.each do |menu_link, attr| %>
      <% if page.link == menu_link %>
        <%= attr[0] %>
      <% else %>
        <a href="<%= weblog.expand_path( menu_link.gsub( %r{^/+}, '' ) ) %>" title="<%= attr[2] %>" 
           accesskey="<%= attr[1] %>"><%= attr[0] %></a>
      <% end %> |
    <% end %>
    <input type="text" id="searchField" name="query" style="font-size: 10px" value="Search" onClick="this.value == 'Search' ? this.value = '' : true">
    </form>
  </div>
sidebar: ~
entry_footer:
  Revision from <%= entry.created.strftime( "%B %d, %Y %H:%M" ) %> by <%= weblog.wiki_link( "authors/" + entry.author ) %>
END
