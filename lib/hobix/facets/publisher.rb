#
# = hobix/facets/publisher.rb
#
# Hobix command-line weblog system, web-based publishing interface.
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

require 'erb'
require 'yaml'

module Hobix
module Facets

# The Publisher plugin adds a web interface for managing Hobix blogs.
# Basically, to add the publisher to your site, ensure the plugin
# is loaded within your hobix.yaml `requires' list:
#
#   requires:
#   - hobix/facets/publisher
#
class Publisher < BaseFacet
    def initialize( weblog, defaults = {} )
        @weblog = weblog
    end
    def get app
        if app.respond_to? :action_uri
            ns, method_id = app.action_uri.split( '/', 2 )
            return false unless ( ns.nil? or ns == "publisher" )

            case method_id
            when /\.js$/
                app.content_type = "text/javascript"
                app.puts File.read( File.join( Hobix::SHARE_PATH, "publisher", method_id ) )
                return true
            when /\.css$/
                app.content_type = "text/css"
                app.puts File.read( File.join( Hobix::SHARE_PATH, "publisher", method_id ) )
                return true
            when /\.png$/
                app.content_type = "image/png"
                app.puts File.read( File.join( Hobix::SHARE_PATH, "publisher", method_id ) )
                return true
            end

            # dispatch the url action
            method_args = (method_id || "config").split( /\// )
            method_id = "config"
            method_args.length.downto(1) do |i|
                if respond_to? "get_#{ method_args[0,i].join( '_' ) }"
                    method_id = "get_#{ method_args.slice!(0,i).join( '_' ) }"
                    break
                end
            end
            method_args.unshift app
            return false unless respond_to? method_id
            @screen = method( method_id ).call( *method_args )
            return true unless @screen

            # Display publisher page
            erb_src = File.read( File.join( Hobix::SHARE_PATH, "publisher/index.erb" ) )
            app.content_type = 'text/html'
            app.puts ::ERB.new( erb_src, nil, nil, "_hobixpublish" ).result( binding )
            return true
        end
    end

    def make_form( form )
        form_erb = %q{
% current = nil
            <style type="text/css">
            <!--
            ul.edit_as_map, ol.edit_as_omap {
                list-style-image:none;
                list-style-type:none;
                margin-top:5px;
                margin:0px;
                padding:0px;
                margin-left:140px;
            }
            ul.edit_as_map li, ol.edit_as_omap li {
                padding: 3px 0px;
                margin: 0px;
            }
            ol.edit_as_omap li .handle {
                cursor: move;
            }
            -->
            </style>
            <h2><%= form[:full_title] %></h2>
            <form id="publisher_form" method="post" enctype="multipart/form-data">
            <p><%= RedCloth.new( form[:intro] ).to_html %></p>
% form[:object].class.properties.each do |name, opts|
%     next unless opts and opts[:edit_as]
%     if sect = form[:object].class.prop_sections.detect { |k,v| v[:__sect] == current }
            <fieldset>
                <legend><%= sect[0] %></legend>
%     end
%     title = name.to_s.gsub( '_', ' ' ).capitalize
%     val = form[:object].instance_variable_get( "@" + name.to_s )
%     if name == :notes
                <div class="notes">
                <h4><%= title %></h4>
                </div>
%     else
                <div class="<%= opts[:req] ? 'required' : 'optional' %>">
                <label for="<%= name %>"><%= title %>:</label>
%         case opts[:edit_as]
%         when :password
                <input type="password" name="<%= name %>" id="<%= name %>"
                       class="inputPassword" size="10" tabindex="" 
                       maxlength="25" value="<%= val %>" />
%         when :checkbox
                <input type="checkbox" name="<%= name %>" id="<%= name %>" 
                       class="inputCheckbox" tabindex="" value="1" />
%         when :textarea
                <textarea name="<%= name %>" id="<%= name %>" rows="<%= opts[:edit_rows] || 4 %>" cols="<%= opts[:edit_cols] || 36 %>" tabindex=""><%= val %></textarea>
%         when :omap
                <ol id="<%= name %>" class="edit_as_omap">
%             val.each_with_index do |(vkey, vval), i|
%                 vkey = vkey.keys.first if vkey.is_a? Hash
                    <li id="<%= name %>_<%= i %>" name="<%= vkey %>">
                        <span class="handle">&raquo;</span>
                        <%= vkey %>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/edit/#{ name }/#{ i }" ) %>">edit</a>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/del/#{ name }/#{ i }" ) %>">remove</a>
                    </li>
%             end if val
                    <li id="<%= name %>_new">
                    <span>&raquo;</span>
                    <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/add/#{ name }" ) %>">add</a>
                    </li>
                </ul>
                <script type="text/javascript" language="javascript">
                // <![CDATA[
                Sortable.create("<%= name %>", {handle:'handle', onUpdate:function () {
                    alert(Sortable.serialize(this.element));
                }});
                // ]]>
                </script>
%         when :map
                <ul id="<%= name %>_order" class="edit_as_map">
%             val.each_with_index do |(vkey, vval), i|
                    <li id="<%= name %>_<%= i %>">
                        <%= vkey %>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/edit/#{ name }/#{ vkey }" ) %>">edit</a>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/del/#{ name }/#{ vkey }" ) %>">remove</a>
                    </li>
%             end if val
                    <li id="<%= name %>_new">
                    <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/add/#{ name }" ) %>">add</a>
                    </li>
                </ul>
%         else
                <input type="text" name="<%= name %>" id="<%= name %>" 
                       class="inputText" size="<%= opts[:edit_size] || 24 %>" tabindex="" 
                       maxlength="255" value="<%= val %>" />
%         end

%         if opts.include? :notes
                <small><%= fopts['notes'] %></small>
%         end
%         if form[:object].respond_to? "default_#{ name }"
                <small><em>Defaults to <strong><%= form[:object].method( "default_#{ name }" ).call %></strong>.</em></small>
%         end
                </div>
%     end
%     current = name
%     if form[:object].class.prop_sections.detect { |k,v| v[:__sect] == current }
            </fieldset>
%     end
% end
            </fieldset>
            <fieldset>
                <div class="submit">
                <div>

                <input type="submit" class="inputSubmit" tabindex="" value="Submit &raquo;" />
                <input type="submit" class="inputSubmit" tabindex="" value="Cancel" />
                </div>
                </div>
            </fieldset>
            </form>
        }
        return ::ERB.new( form_erb, 0, "%<>", "_hobixpublishFORM" ).result( binding )
    end

    def save_form( obj )
        obj = obj.dup
        obj.class.properties.each do |name, opts|
            case opts[:edit_as]
            when :omap
                obj
            else
                obj
            end
        end
    end

    def get_config( app )
        @title = 'config'
        case app.request_method
        when "GET"
            make_form :app => app,
              :full_title => 'Configure Your Weblahhg',
              :intro => %q{
                  Generally speaking, you shouldn't have to alter many of your weblog settings.
                  Most of the below are available for those who really want to customize.
                  
                  **Bold** fields are required.
              }.gsub( /^ +/, '' ),
              :object => @weblog
        when "POST"
            # weblog = save_form( @weblog )
            app._POST.inspect
        end
    end

    def get_entries( app, *entry_id )
        @title = 'entries'
        unless entry_id.empty?
            e = @weblog.storage.load_entry( entry_id.join( '/' ) )
        else
            e = Hobix::Entry.new
        end
        case app.request_method
        when "GET"
            make_form :app => app,
              :full_title => 'Post an Entry',
              :intro => %q{
                  **Bold** fields are required.
              }.gsub( /^ +/, '' ),
              :object => e
        when "POST"
            # weblog = save_form( @weblog )
            app._POST.inspect
        end
    end
end

end
end
