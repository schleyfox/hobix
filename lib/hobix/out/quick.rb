#
# = hobix/out/quick.rb
#
# Quick YAML + ERb templates which makes templating
# thirty times easier!!
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
require 'erb'

module Hobix
module Out
class QuickError < StandardError; end

class Quick < Hobix::BaseOutput
    def initialize( weblog, defaults = {} )
        @path = weblog.skel_path
        defaults.each do |k, v|
            if respond_to? "#{ k }_erb"
                instance_eval %{
                    def #{ k }_erb
                        <<-QUICK
                        #{ v }
                        QUICK
                    end
                }
            end
        end
    end
    def extension
        "quick"
    end
    def load( file_name, vars )
        @bind = binding
        @relpath = File.dirname( file_name )
        vars.each do |k, v|
            eval( "#{ k } = vars[#{ k.inspect }]", @bind )
        end
        quick_file = File.read( file_name )
        quick_data = if quick_file.strip.empty?
                         {}
                     else
                         YAML::load( quick_file )
                     end
        erb_src = make( 'page', quick_data, vars.has_key?( :entries ) )
        erb = ::ERB.new( erb_src )
        begin
            erb.result( @bind )
        rescue Exception => e
            raise QuickError, "Error `#{ e.message }' in erb #{ file_name }."
        end
    end
    def expand( fname )
        if fname =~ /^\//
            File.join( @path, fname )
        else
            File.join( @relpath, fname )
        end
    end
    def make( part, quick_data, has_entries = true )
        if part == 'entries' and not has_entries
            part = 'entry'
        end
        erb = quick_data[part] || method( "#{ part }_erb" ).call
        if erb.respond_to? :gsub
            erb.gsub( /<\+\s*(\w+)\s*\+>/ ) do
                make( $1, quick_data, has_entries )
            end.gsub( /<\+\s*([\w\.\/\\\-]+)\s*\+>/ ) do
                File.read( expand( $1 ) )
            end
        elsif erb.respond_to? :collect
            erb.collect do |inc|
                make( inc, quick_data, has_entries )
            end.join "\n"
        end
    end

    #
    # Default quick templates
    #
    def title_erb; '<%= weblog.title %>'; end
    def banner_erb
     %{ <div id="banner">
        <h1 class="title"><a href="<%= weblog.link %>"><%= weblog.title %></a></h1>
        <div class="tagline"><%= weblog.tagline %></div>
        </div> }
    end
    def sidebar_erb
     %{ <div id="sidebar">
        <+ sidebar_list +>
        </div> }
    end
    def sidebar_list_erb
        ['sidebar_archive', 'sidebar_links', 'sidebar_syndicate', 'sidebar_hobix']
    end
    def sidebar_archive_erb
     %{ <div id="sidebarBox">
        <h2 class="sidebarTitle">Archive</h2>
        <% months = weblog.storage.get_months( weblog.storage.find ) %>
        <% months.each do |month_start, month_end, month_id| %>
            <a href="<%= month_id %>"><%= month_start.strftime( "%B %Y" ) %></a><br />
        <% end %>
        </div> }
    end
    def sidebar_links_erb
     %{ <div id="sidebarBox">
        <h2 class="sidebarTitle">Links</h2>
        <%# weblog.links.to_html %>
        </div> }
    end
    def sidebar_syndicate_erb
     %{ <div id="sidebarBox">
        <h2 class="sidebarTitle">Syndicate</h2>
        <a href="/index.xml">RSS 2.0</a>
        </div> }
    end
    def sidebar_hobix_erb
     %{ <div id="sidebarBox">
        Built upon <a href="http://hobix.com">Hobix</a>
        </div> }
    end
    def entries_erb
     %{ <div id="blog">
        <% entries.each_day do |day, day_entries| %>
            <+ day_header +>
            <% day_entries.each do |entry| %>
                <+ entry +>
            <% end %>
        <% end %>
        </div> }
    end
    def day_header_erb; %{ <h2 class="dayHeader"><%= day.strftime( "%A, %B %d, %Y" ) %></h2> }; end
    def entry_erb
     %{ <div class="entry">
            <+ entry_title +>
            <+ entry_content +>
        </div>
        <div class="entryFooter"><+ entry_footer +></a>
        </div> }
    end
    def entry_title_erb
     %{ <h3 class="entryTitle"><%= entry.title %></h3>
        <% if entry.tagline %><div class="entryTagline"><%= entry.tagline %></div><% end %> }
    end
    def entry_content_erb
        %{ <div class="entryContent"><%= entry.content.to_html %></div> }
    end
    def entry_footer_erb
     %{ posted by <%= entry.author %> | <a href="<%= entry.link %>"><%= entry.created.strftime( "%I:%M %p" ) %> }
    end
    def css_erb; %{ @import "/site.css"; }; end
    def doctype_erb
     %{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">}
    end
    def page_erb
     %{<+ doctype +>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title><+ title +></title>
<style type="text/css">
<+ css +>
</style>
</head>
<body>

<div id="page">

<+ banner +>

<div id="content">
<+ sidebar +>

<+ entries +>

</div>
</div>

</body>
</html>}
    end
end

class QuickSummary < Quick
    def extension
        "quick-summary"
    end
    def entry_content_erb
     %{ <div class="entryContent">
        <% if entry.summary %>
        <%= entry.summary.to_html %>
        <p><a href="<%= entry.link %>">Continue to full post.</a></p>
        <% else %>
        <%= entry.content.to_html %>
        <% end %>
        </div> }
    end
end

class QuickArchive < Quick
    def extension
        "quick-archive"
    end
    def entry_erb
     %{ <h3 class="entryTitle"><a href="<%= entry.link %>"><%= entry.title %></a></h3> }
    end
    def entries_erb
     %{ <div id="blog">
        <div id="archives">
        <ul>
        <% entries.each_day do |day, day_entries| %>
            <li><+ day_header +></li>
            <ul>
            <% day_entries.each do |entry| %>
                <li><+ entry +></li>
            <% end %>
            </ul>
            </li>
        <% end %>
        </ul>
        </div>
        </div> }
    end
end

end
end
