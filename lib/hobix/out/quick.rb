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
    def title_erb; "<%= weblog.title %>"; end
    def banner_erb
        <<-QUICK
        <h1 class="title"><a href="<%= weblog.link %>"><%= weblog.title %></a></h1>
        <div class="tagline"><%= weblog.tagline %></span>
        QUICK
    end
    def sidebar_erb
        ['sidebar_archive', 'sidebar_links', 'sidebar_syndicate', 'sidebar_hobix']
    end
    def sidebar_archive_erb
        <<-QUICK
        <div id="sidebarBox">
        <h2 class="sidebarTitle">Archive</h2>
        <% months = weblog.storage.get_months( weblog.storage.find ) %>
        <% months.each do |month_start, month_end, month_id| %>
            <a href="<%= month_id %>"><%= month_start.strftime( "%B %Y" ) %></a><br />
        <% end %>
        </div>
        QUICK
    end
    def sidebar_links_erb
        <<-QUICK
        <div id="sidebarBox">
        <h2 class="sidebarTitle">Links</h2>
        <%# weblog.links.to_html %>
        </div>
        QUICK
    end
    def sidebar_syndicate_erb
        <<-QUICK
        <div id="sidebarBox">
        <h2 class="sidebarTitle">Syndicate</h2>
        <a href="/index.xml">RSS 2.0</a>
        </div>
        QUICK
    end
    def sidebar_hobix_erb
        <<-QUICK
        <div id="sidebarBox">
        Built upon <a href="http://hobix.com">Hobix</a>
        </div>
        QUICK
    end
    def entries_erb
        <<-QUICK
        <% entries.each_day do |day, day_entries| %>
            <h2 class="dayHeader"><+ day_header +></h2>
            <% day_entries.each do |entry| %>
                <+ entry +>
            <% end %>
        <% end %>
        QUICK
    end
    def day_header_erb; "<%= day.strftime( '%A, %B %d, %Y' ) %>"; end
    def entry_erb
        <<-QUICK
        <div class="entry">
            <h3 class="entryTitle"><+ entry_title +></h3>
            <div class="entryContent"><+ entry_content +></div>
        </div>
        <div class="entryFooter"><+ entry_footer +></a>
        </div> 
        QUICK
    end
    def entry_title_erb; '<%= entry.title %></h3>'; end
    def entry_content_erb; '<%= entry.content.to_html %>'; end
    def entry_footer_erb
        'posted by <%= entry.author %> | <a href="<%= entry.link %>"><%= entry.created.strftime( "%I:%M %p" ) %>'
    end
    def css_erb; '@import "/site.css";'; end
    def doctype_erb
        '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'
    end
    def page_erb
        <<QUICK
<+ doctype +>
<html>
<title><+ title +></title>
<style type="text/css">
<+ css +>
</style>
</head>
<body>

<div id="page">

<div id="banner">
<+ banner +>
</div>

<div id="content">
<div id="sidebar">
<+ sidebar +>
</div>

<div id="blog">
<+ entries +>
</div>

</div>
</div>

</body>
</html>
QUICK
    end
end
end
end
