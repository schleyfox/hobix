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
    class MissingRequired < Exception; end

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
            <script type="text/javascript" language="javascript">
            // <![CDATA[
            function sortable_to_csv(element) {
                var element = $(element);
                var options = {
                    tag:  element.sortable.tag,
                    only: element.sortable.only,
                    name: element.id
                }.extend(arguments[1] || {});

                var items = $(element).childNodes;
                var queryComponents = new Array();

                for(var i=0; i<items.length; i++)
                    if(items[i].tagName && items[i].tagName==options.tag.toUpperCase() &&
                        (!options.only || (Element.Class.has(items[i], options.only))))
                            queryComponents.push(items[i].id.replace(element.id+'_',''));

                return queryComponents;
            }
            // ]]>
            </script>
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
                <ol id="<%= name %>sort" class="edit_as_omap">
%             val.each do |vkey, vval|
%                 vkey = vkey.keys.first if vkey.is_a? Hash
                    <li id="<%= name %>sort_<%= vkey %>" class="sorty" name="<%= vkey %>">
                        <span class="handle">&raquo;</span>
                        <%= vkey %>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/edit/#{ name }/#{ vkey }" ) %>">edit</a>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/del/#{ name }/#{ vkey }" ) %>">remove</a>
                    </li>
%             end if val
                    <li class="new_item">
                    <span>&raquo;</span>
                    <input type="text" name="<%= name %>_new" id="<%= name %>_new" style="width:150px" 
                           class="inputText" tabindex="" maxlength="255" value="" />
                    <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/add/#{ name }" ) %>">add</a>
                    </li>
                </ul>
                <input type="hidden" name="<%= name %>" id="<%= name %>" value="" />
                <script type="text/javascript" language="javascript">
                // <![CDATA[
                Sortable.create("<%= name %>sort", {handle:'handle', only: 'sorty', onUpdate:function () {
                    $("<%= name %>").value = sortable_to_csv(this.element).join(' ');
                }});
                // ]]>
                </script>
%         when :map
                <ul id="<%= name %>_order" class="edit_as_map">
%             val.each do |vkey, vval|
                    <li id="<%= name %>_<%= vkey %>">
                        <%= vkey %>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/edit/#{ name }/#{ vkey }" ) %>">edit</a>
                        <a href="<%= form[:app].absuri( :path_info => "/publisher/#{ @title }/del/#{ name }/#{ vkey }" ) %>">remove</a>
                    </li>
%             end if val
                    <li id="new_item">
                    <input type="text" name="<%= name %>_new" id="<%= name %>_new" style="width:150px"
                           class="inputText" tabindex="" maxlength="255" value="" />
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

    def save_form( obj, app )
        obj = obj.dup
        missing = []
        obj.class.properties.each do |name, opts|
            next unless opts
            next unless app._POST.has_key? name.to_s
            val = app._POST[name.to_s]
            val = nil if val and val.empty?
            missing << name if val.nil? and opts[:req]

            case opts[:edit_as]
            when :omap
                omap = obj.instance_variable_get( "@#{name}" )
                sorted = val.to_s.split(/\s+/)
                sorted.each { |item| omap << [item] unless omap.assoc(item) }
                omap.sort_by { |item, val| sorted.index(item) || sorted.length }
            when :map
                map = obj.instance_variable_get( "@#{name}" )
                val.to_s.split(/\s+/).each do |item|
                    map[item] ||= nil
                end
            else
                obj.instance_variable_set( "@#{name}", val )
            end
        end
        [obj, missing]
    end

    def red( str ); RedCloth.new( str ).to_html; end

    def show_weblog_form( weblog, app )
        make_form :app => app,
          :full_title => 'Configure Your Weblahhg',
          :intro => %q{
              Generally speaking, you shouldn't have to alter many of your weblog settings.
              Most of the below are available for those who really want to customize.
              
              **Bold** fields are required.
          }.gsub( /^ +/, '' ),
          :object => weblog
    end

    def get_config( app )
        @title = 'config'
        case app.request_method
        when "GET"
            show_weblog_form( @weblog, app )
        when "POST"
            weblog, missing = save_form( @weblog, app )
            # if missing.empty?
            #     weblog.save( weblog.hobix_yaml + ".edit" )
            #     red %{
            #         *Your configuraton has been saved.*
            #         
            #         Please note that this development version of Hobix isn't
            #         yet equipped to deal with re-sorting of the requires.  I'm not that great with Prototype
            #         yet and I also want to write some code to sandbox the configuration, to check that the
            #         requires will load right before saving it.
            #     }
            # else
            #     show_weblog_form( weblog, app )
            # end
            [weblog, missing].to_yaml
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
            e, missing = save_form( e, app )
            e.inspect
        end
    end
end

end
end
