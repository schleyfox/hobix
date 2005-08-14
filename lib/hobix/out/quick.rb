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
# This program is free software, released under a BSD license.
# See COPYING for details.
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
    APPEND_TPL_RE = /^(.+)\s*(<<|>>)$/
    # Class method for appending to a method template
    def self.append_def( method, str )
        newstr = "#{ self.allocate.method( method ).call }#{ str }"
        define_method( method ) { newstr }
    end
    # Class method for prepending to a method template
    def self.prepend_def( method, str )
        newstr = "#{ str }#{ self.allocate.method( method ).call }"
        define_method( method ) { newstr }
    end

    def initialize( weblog, defaults = {} )
        @hobix_path = weblog.path
        @path = weblog.skel_path
        defaults.each do |k, v|
            k = k.gsub( /\W/, '_' )
            k.untaint
            v = v.inspect
            v.untaint
            if k =~ APPEND_TPL_RE
                k = $1.strip
                v = if $2 == ">>"
                        "#{ v } + #{ k }_erb_orig"
                    else
                        "#{ k }_erb_orig + #{ v }"
                    end
                instance_eval %{
                    alias #{ k }_erb_orig #{ k }_erb
                    def #{ k }_erb
                        #{ v }
                    end
                }
            else
                instance_eval %{
                    def #{ k }_erb
                        #{ v }
                    end
                }
            end
        end
    end
    def setup
        quick_conf = File.join( @hobix_path, 'hobix.out.quick' )
        unless File.exists? quick_conf
            quicksand = {}
            methods.each do |m|
                if m =~ /^(.+)_erb$/
                    key = $1
                    qtmpl = method( m ).call
                    if qtmpl.respond_to? :strip
                        qtmpl = "\n#{ qtmpl.strip.gsub( /^ {8}/, '' ) }\n"
                        def qtmpl.to_yaml_fold; '|'; end
                    end
                    quicksand[key] = qtmpl
                end
            end
            File.open( quick_conf, 'w' ) do |f|
                YAML.dump( quicksand, f )
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
            k.untaint
            k_inspect = k.inspect.untaint
            eval( "#{ k } = vars[#{ k_inspect }]", @bind )
        end
        quick_file = File.read( file_name )
        quick_data = if quick_file.strip.empty?
                         {}
                     else
                         YAML::load( quick_file )
                     end
        quick_data.each do |k, v|
            if k =~ APPEND_TPL_RE
                k = $1.strip
                quick_data[k] = if $2 == ">>"
                                    v + method( "#{ k }_erb" ).call
                                else
                                    method( "#{ k }_erb" ).call + v
                                end
            end
        end
        erb_src = make( 'page', quick_data, vars.has_key?( :entries ) )
        erb_src.untaint
        erb = ::ERB.new( erb_src )
        begin
            erb.result( @bind )
        rescue Exception => e
            puts "--- erb source ---"
            puts erb_src
            puts "--- erb source ---"
            puts e.backtrace
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
        erb = quick_data[part] || method( "#{ part.gsub( /\W+/, '_' ) }_erb" ).call
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
    def footer_erb; end
    def sidebar_erb
     %{ <div id="sidebar">
        <+ sidebar_list +>
        </div> }
    end
    def sidebar_list_erb
        ['sidebar_archive', 'sidebar_links', 'sidebar_syndicate', 'sidebar_hobix']
    end
    def sidebar_archive_erb
     %{ <div class="sidebarBox">
        <h2 class="sidebarTitle">Archive</h2>
        <ul>
        <% months = weblog.storage.get_months( weblog.storage.find ) %>
        <% months.reverse.each do |month_start, month_end, month_id| %>
            <li><a href="<%= weblog.expand_path month_id %>"><%= month_start.strftime( "%B %Y" ) %></a></li>
        <% end %>
        </ul>
        </div> }
    end
    def sidebar_links_erb
     %{ <div class="sidebarBox">
        <h2 class="sidebarTitle">Links</h2>
        <%= weblog.linklist.content.to_html %>
        </div> }
    end
    def sidebar_syndicate_erb
     %{ <div class="sidebarBox">
        <h2 class="sidebarTitle">Syndicate</h2>
        <ul>
            <li><a href="<%= weblog.link %>/index.xml">RSS 2.0</a></li>
        </ul>
        </div> }
    end
    def sidebar_hobix_erb
     %{ <div class="sidebarBox">
        <p>Built upon <a href="http://hobix.com">Hobix</a></p>
        </div> }
    end
    def blog_erb
     %{ <div id="blog">
        <+ entries +>
        </div> }
    end
    def entries_erb
     %{ <% entries.each_day do |day, day_entries| %>
            <a name="<%= day.strftime( "%Y%m%d" ) %>"></a>
            <+ day_header +>
            <% day_entries.each do |entry| %>
                <+ entry +>
            <% end %>
        <% end %> }
    end
    def day_header_erb; %{ <h2 class="dayHeader"><%= day.strftime( "%A, %B %d, %Y" ) %></h2> }; end
    def entry_erb
     %{ <div class="entry">
            <+ entry_title +>
            <+ entry_content +>
        </div>
        <div class="entryFooter"><+ entry_footer +></div> }
    end
    def entry_title_erb
     %{ <h3 class="entryTitle"><%= entry.title %></h3>
        <% if entry.respond_to? :tagline and entry.tagline %><div class="entryTagline"><%= entry.tagline %></div><% end %> }
    end
    def entry_content_erb
        %{ <div class="entryContent"><%= entry.content.to_html %></div> }
    end
    def entry_footer_erb
     %{ posted by <%= weblog.authors[entry.author]['name'] %> | <a href="<%= entry.link %>"><%= entry.created.strftime( "%I:%M %p" ) %></a> }
    end
    def head_tags_erb; end
    def css_erb; %{ @import "<%= weblog.expand_path "site.css" %>"; }; end
    def doctype_erb
     %{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">}
    end
    def page_erb
     %{<+ doctype +>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title><+ title +></title>
<+ head_tags +>
<style type="text/css">
<+ css +>
</style>
</head>
<body>

<div id="page">

<+ banner +>

<div id="content">
<+ sidebar +>

<+ blog +>

</div>

<+ footer +>

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
        <% if entry.respond_to? :summary and entry.summary %>
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
     %{ <div id="archives">
        <ul>
        <% entries.each_day do |day, day_entries| %>
            <li><+ day_header +>
            <ul>
            <% day_entries.each do |entry| %>
                <li><+ entry +></li>
            <% end %>
            </ul>
            </li>
        <% end %>
        </ul>
        </div> }
    end
end

end
end
