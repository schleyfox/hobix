#
# = hobix/weblog.rb
#
# Hobix command-line weblog system.
#
# Copyright (c) 2003-2004 why the lucky stiff
# Copyright (c) 2005-2007 MenTaLguY
#
# Written & maintained by why the lucky stiff <why@ruby-lang.org>
# Additional bits by MenTaLguY <mental@rydia.net>
#
# This program is free software, released under a BSD license.
# See COPYING for details.
#
#--
# $Id$
#++
require 'hobix/base'
require 'hobix/entry'
require 'hobix/linklist'
require 'find'
require 'ftools'
require 'uri'
require 'yaml'

module Hobix
# The UriStr mixin ensures that URIs are supplied a to_str
# method and a to_yaml method which allows the URI to act more
# like a string.  In most cases, Hobix users will be using URIs
# as strings.
module UriStr
    def to_str; to_s; end
    def to_yaml( opts = {} )
        self.to_s.to_yaml( opts )
    end
    def rooturi
        rooturi = dup
        rooturi.path = ''
        rooturi
    end
end

#
# The Page class is very simple class which contains information
# specific to a template.
#
# == Introduction
#
# The +id+, +next+ and +prev+ accessors
# provide ids for the current page and its neighbors
# (for example, in the case of monthly archives, which may have
# surrounding months.)
#
# To get complete URLs for each of the above, use: +link+,
# +next_link+, and +prev_link+.
#
# The +timestamp+ accessor contains the earliest date pertinent to
# the page.  For example, in the case of a monthly archive, it
# will contain a +Time+ object for the first day of the month.
# In the case of the `index' page, you'll get a Time object for
# the earliest entry on the page.
#
# The +updated+ accessor contains the latest date pertinent to
# the page.  Usually this would be the most recent modification
# time among entries on the page.  This accessor is used by the
# regeneration system to determine if a page needs regeneration.
# See +Hobix::Weblog#regenerate+ for more.
#
# == Context in Hobix
#
# There are only two places you'll encounter this class in Hobix.
#
# If you are writing an output plugin, a Page class is passed in
# the _vars_ hash to the +BaseOutput#load+ method.  You'll find
# the class in vars[:page].
#
# If you are writing ERB or RedRum templates, these vars are passed
# into the templates.  The Page class is accessible as a variable
# called `page'.
#
# = Examples
#
# == Example 1: Pagination in a Template
#
# Let's say we want every entry in our site to contain links to
# the entries which are chronologically nearby.
#
# If we're using RedRum templates, we could do the following
# in entry.html.redrum:
#
#   <% if page.prev %>"last":<%= page.prev_link %><% end %>
#   <% if page.next %>"next":<%= page.next_link %><% end %>
#
class Page
    attr_reader :id
    attr_accessor :link, :next, :prev, :timestamp, :updated
    def initialize( id, dir='.' )
        @id, @dir = id, dir
    end
    def id; dirj( @dir, @id ).gsub( /^\/+/, '' ); end
    def link; dirj( @dir, @id ) + @ext; end
    def next_link; dirj( @dir, @next ) + @ext if @next; end
    def prev_link; dirj( @dir, @prev ) + @ext if @prev; end
    def dirj( dir, link ) #:nodoc:
        if link[0] != ?/ and link != '.' 
            link = File.join( dir == '.' ? "/" : dir, link )
        end
        link
    end
    def add_ext( ext ) #:nodoc:
        @ext = ext
    end
    def reference_fields; [:next, :prev]; end
    def references; reference_fields.map { |f| self.send f }.compact; end
end
#
# The Weblog class is the core of Hobix scripting.  Although often
# you use it's +storage+ accessor to get to entries, the Weblog
# class itself contains weblog configuration information and
# methods for managing the weblog.
#
# == Properties
#
# The following accessors are available for retrieving configuration
# data, all of which is stored in hobix.yaml.
#
# title::          The title of the weblog.
# link::           The absolute url to the weblog.  (When accessed through
#                  the class -- weblog.link -- this is returned as a URI.)
# authors::        A hash, in which keys are author's abbreviated names,
#                  paired with hashes of `name', `url' and `email'
#                  information.
# contributors::   Same structure as the authors hash.  For storing
#                  information on third-party contributors.
# tagline::        The short catchphrase associated with the weblog.
# copyright::      Brief copyright information.
# period::         How often is the weblog updated?  Frequency in seconds.
# path::           Complete system path to the directory containing
#                  hobix.yaml.
# sections::       Specially tagged directories which act as independent
#                  subsites or hidden categories.
# requires::       A list of required libraries, paired with possible
#                  configuration data for a library.
# entry_path::     Path to entry storage.
# skel_path::      Path to template's directory.
# output_path::    Path to output directory.
# lib_path::       Path to extension library directory.
#
# git::            If true, regenerations will commit to git and push the
#                  site to the blahg remote.
#
# == Regeneration
#
# One of the primary uses of the Weblog class is to coordinate
# regenerations of the site.  More about regeneration can be found
# in the documentation for the +regenerate+ method.
#
# == Skel Methods
#
# The Weblog class also contains handlers for template prefixes.
# (Templates are usually contained in `skel').
#
# Each `prefix' has its accompanying skel_prefix method.  So, for
# `index' templates (such as index.html.erb), the skel_index method
# is executed and passed a block which is supplied a hash by the skel
# method.
#
# Usually this hash only needs to contain :page and :entries (or :entry)
# items.  Any other items will simply be added to the vars hash.
#
# To give you a general idea, skel_index looks something like this:
#
#   def skel_index( path_storage, section_path )
#       index_entries = path_storage.lastn( @lastn )
#       page = Page.new( 'index', section_path )
#       page.prev = index_entries.last.created.strftime( "%Y/%m/index" )
#       page.timestamp = index_entries.first.created
#       page.updated = path_storage.last_updated( index_entries )
#       yield :page => page, :entries => index_entries
#   end
#
# The page object is instantiated, describing where output will go.
# The entries list, describing which entries qualify for this prefix,
# is queried from storage.  We then yield back to the regeneration
# system with our hash.
#
# Creating your own template prefixes is simply a matter of adding
# a new skel method for that prefix to the Weblog class.
#
# = Examples
#
# == Example 1: Viewing Configuration
#
# Since configuration is stored in YAML, you can generate the hobix.yaml
# configuration file by simply running +to_yaml+ on a weblog.
#
#   require 'hobix/weblog'
#   weblog = Hobix::Weblog.load( '/my/blahhg/hobix.yaml' )
#   puts weblog.to_yaml
#     #=> --- # prints YAML configuration
#
# == Example 2: Adding a Template Prefix
#
# On Hobix.com, only news entries are shown on the front page.  The
# site also has `about' and `learn' entry paths for storing the faqs
# and tutorials.  Although I didn't want to display the complete
# text of these items, I did want a sidebar to contain links to them.
#
# So I added a `sidebar' prefix, which loads from these entry paths.
# I have a sidebar.html.erb, which is included using Apache SSIs.
# The advantage to this approach is that when an update occurs in
# either of these paths, the sidebar will be updated in the next
# regeneration.  Rather than having to regenerate every page in the
# site to see the change reflected.
#
# I added a `lib/hobix.com.rb' to the site's `lib' directory.  And
# in hobix.yaml, I included a line requiring this file.  The file
# simply contains the new skel method.
#
#   module Hobix
#   class Weblog
#       def skel_sidebar( path_storage, section_path )
#           ## Load `about' and `learn' entries
#           abouts = path_storage.find( :all => true, :inpath => 'about' ).reverse
#           learns = path_storage.find( :all => true, :inpath => 'learn' ).reverse
#   
#           ## Create page data
#           page = Page.new( 'sidebar', section_path )
#           page.updated = path_storage.last_updated( abouts + learns )
#           yield :page => page, 
#                 :about_entries => abouts, :learn_entries => learns
#       end
#   end
#   end
#
# There is a lot going on here.  I'll try to explain the most vital parts and
# leave the rest up to you.
#
# First, storage queries don't return full Entry objects.  You can read more
# about this in the +Hobix::BaseStorage+ class docs.  The storage query returns
# Arrays which contain each entry's id (a String) and the entry's modification time
# (a Time object).
#
# See, the regeneration system will do the business of loading the full entries.
# The skel method's job is just to report which entries *qualify* for a
# template.  The regeneration system will only load those entries
# if an update is needed.
#
# We create a Page object, which dictates that the output will be saved to
# /sidebar.ext.  A modification time is discovered by passing a combined list
# to +Hobix::BaseStorage#last_updated+.  The +updated+ property is being
# set to the latest timestamp among the about and learn entries.
#
# PLEASE NOTE: The +updated+ property is very important.  The regeneration
# system will use this timestamp to determine what pages need updating.
# See +Hobix::Weblog#regenerate+ for more.
#
# We then yield to the regeneration system.  Note that any hash key which
# ends with `entries' will have its contents loaded as full Entry objects, should
# the prefix qualify for regeneration.
#
# == The page_storage variable
#
# The +page_storage+ variable passed into the method is a trimmed copy of the
# +Weblog#storage+ variable.  Whereas +Weblog#storage+ gives you access to all
# stored entries, +page_storage+ only gives you access to entries within
# a certain path.
#
# So, if you have a template skel/index.html.quick, then this template will
# be passed a +path_storage+ variable which encompasses all entries.  However,
# for template skel/friends/eric/index.html.quick will be given a
# +path_storage+ which includes only entries in the `friends/eric' path.
#
# The simple rule is: if you want to have access to load from the entire
# weblog storage, use +storage+.  If you want your template to honor its
# path, use +path_storage+.  Both are +Hobix::BaseStorage+ objects and
# respond to the same methods.
class Weblog
    include BaseProperties

    _! 'Basic Information'
    _ :title,              :req => true, :edit_as => :text
    _ :link,               :req => true, :edit_as => :text
    _ :tagline,            :req => true, :edit_as => :text
    _ :copyright,          :edit_as => :text
    _ :period,             :edit_as => :text
    _ :lastn,              :edit_as => :text

    _! 'Entry Customization'
    _ :entry_class,        :edit_as => :text
    _ :index_class,        :edit_as => :text
    _ :central_prefix,     :edit_as => :text
    _ :central_ext,        :edit_as => :text

    _! 'Paths'
    _ :entry_path,         :edit_as => :text
    _ :lib_path,           :edit_as => :text
    _ :skel_path,          :edit_as => :text
    _ :output_path,        :edit_as => :text

    _! 'Participants'
    _ :authors,            :req => true, :edit_as => :map 
    _ :contributors,       :edit_as => :map
    
    _! 'Links'
    _ :linklist,           :edit_as => :omap

    _! 'Sections'
    _ :sections,           :edit_as => :map

    _! 'Libraries and Plugins'
    _ :requires,           :req => true, :edit_as => :omap

    _ :git,                :edit_as => :text
    
    attr_accessor :path
    attr_reader   :hobix_yaml

    # After the weblog is initialize, the +start+ method is called
    # with the full system path to the directory containing the configuration.
    #
    # This method sets up all the paths and loads the plugins.
    def start( hobix_yaml )
        @hobix_yaml = hobix_yaml
        @path = File.dirname( hobix_yaml )
        @sections ||= {}
        if File.exists?( lib_path )
            $LOAD_PATH << lib_path
        end
        @plugins = []
        @requires.each do |req|
            opts = nil
            unless req.respond_to? :to_str
                req, opts = req.to_a.first
            end
            plugin_conf = File.join( @path, req.gsub( /\W+/, '.' ) )
            if File.exists? plugin_conf
                puts "*** Loading #{ plugin_conf }"
                plugin_conf = YAML::load_file plugin_conf
                if opts
                    opts.merge! plugin_conf
                else
                    opts = plugin_conf
                end
            end
            @plugins += Hobix::BasePlugin::start( req, opts, self )
        end
    end

    def default_entry_path; "entries"; end
    def default_skel_path; "skel"; end
    def default_output_path; "htdocs"; end
    def default_lib_path; "lib"; end
    def default_central_prefix; "entry"; end
    def default_central_ext; "html"; end
    def default_entry_class; "Hobix::Entry"; end
    def default_index_class; "Hobix::IndexEntry"; end

    def entry_path; File.expand_path( @entry_path || default_entry_path, @path ).untaint; end
    def skel_path; File.expand_path( @skel_path || default_skel_path, @path ).untaint; end
    def output_path; File.expand_path( @output_path || default_output_path, @path ).untaint; end
    def lib_path; File.expand_path( @lib_path || default_lib_path, @path ).untaint; end
    def central_prefix; @central_prefix =~ /^[\w\.]+$/ ? @central_prefix.untaint : default_central_prefix; end
    def central_ext; @central_ext =~ /^\w*$/ ? @central_ext.untaint : default_central_ext; end
    def entry_class( tag = nil )
        tag = @entry_class =~ /^[\w:]+$/ ? @entry_class.untaint : default_entry_class unless tag
            
        found_class = nil
        if @@entry_classes
            found_class = @@entry_classes.find do |c|
                tag == c.name.split( '::' ).last.downcase
            end
        end

        begin
            found_class || Hobix.const_find( tag )
        rescue NameError => e
            raise NameError, "No such entry class #{ tag }"
        end
    end
    def index_class( tag = nil )
        tag = @index_class =~ /^[\w:]+$/ ? @index_class.untaint : default_index_class unless tag
        begin
            Hobix.const_find( tag )
        rescue NameError => e
            raise NameError, "No such index class #{ tag }"
        end
    end

    def link
        URI::parse( @link.gsub( /\/$/, '' ) ).extend Hobix::UriStr
    end

    def linklist
        if @linklist.class == ::Array
            YAML::transfer( 'hobix.com,2004/linklist', {'links' => @linklist} )
        else
           @linklist
        end
    end

    # Translate paths relative to the weblahhg's URL.  This is especially important
    # if a weblog isn't at the root directory for a domain.
    def expand_path( path )
        File.expand_path( path.gsub( /^\/+/, '' ), self.link.path.gsub( /\/*$/, '/' ) )
    end

    # Load the weblog information from a YAML file and +start+ the Weblog.
    def Weblog::load( hobix_yaml )
        hobix_yaml = File.expand_path( hobix_yaml )
        weblog = YAML::load( File::open( hobix_yaml ) )
        weblog.start( hobix_yaml )
        weblog
    end

    # Save the weblog configuration to its hobix.yaml (or optionally
    # provide a path where you would like to save.)
    def save( file = @hobix_yaml )
        unless file
            raise ArgumentError, "Missing argument: path to save configuration (0 of 1)"
        end
        File::open( file, 'w' ) do |f|
            YAML::dump( self, f )
        end
        self
    end

    # Used by +regenerate+ to construct the vars hash by calling
    # the appropriate skel method for each page.
    def build_pages( page_name )
        vars = {}
        paths = page_name.split( '/' )
        loop do
            try_page = paths.join( '_' ).gsub('-','_')
            if respond_to? "skel_#{ try_page }"
                section_path = File.dirname( page_name )
                path_storage = storage.path_storage( section_path )
                method( "skel_#{ try_page }" ).call( path_storage, section_path ) do |vars|
                    vars[:weblog] = self
                    raise TypeError, "No `page' variable returned from skel_#{ try_page }." unless vars[:page]
                    yield vars
                end
                return
            end
            break unless paths.slice!( -2 )  ## go up a directory
        end
        vars[:weblog] = self
        vars[:page] = Page.new( page_name )
        vars[:page].timestamp = Time.now
        yield vars
    end

    # Sets up a weblog.  Should only be run once (which Hobix
    # performs automatically upon blog creation).
    def setup
        @plugins.each do |p|
            if p.respond_to? :setup
                p.setup
            end
        end
    end

    # Returns the storage plugin currently in use.  (There
    # can be only one per weblog.)
    def storage
        @plugins.detect { |p| p.is_a? BaseStorage }
    end

    # Returns an Array of all output plugins in use.  (There can
    # be many.)
    def outputs
        @plugins.find_all { |p| p.is_a? BaseOutput }
    end

    # Returns an Array of all publisher plugins in use.  (There can
    # be many.)
    def publishers
        @plugins.find_all { |p| p.is_a? BasePublish }
    end

    # Returns an Array of all facet plugins in use.  (There can
    # be many.)
    def facets
        @plugins.find_all { |p| p.is_a? BaseFacet }
    end

    def facet_for( app )
        facets.each { |p| return if p.get app }
        Hobix::BaseFacet.not_found app
    end

    # Clears the hash used to cache the results of +output_map+.
    def reset_output_map; @output_map = nil; end

    # Reads +skel_path+ for templates and builds a hash of all the various output
    # files which will be generated.  This method will cache the output_map once.
    # Subsequent calls to +output_map+ will quickly return the cached hash.  To reset
    # the cache, use +reset_output_map+.
    def output_map
        @output_map ||= nil
        return @output_map if @output_map
        path_watch = {}
        @output_entry_map = {}
        Find::find( skel_path ) do |path|
            path.untaint
            if File.basename(path)[0] == ?.
                Find.prune 
            elsif not FileTest.directory? path
                tpl_path = path.gsub( /^#{ Regexp::quote( skel_path ) }\/?/, '' )
                output = outputs.detect { |p| if tpl_path =~ /\.#{ p.extension }$/; tpl_path = $`; end }
                if output
                    ## Figure out template extension and output filename
                    page_name, tpl_ext = tpl_path.dup, ''
                    while page_name =~ /\.\w+$/; page_name = $`; tpl_ext = $& + tpl_ext; end
                    next if tpl_ext.empty?
                    ## Build the output pages
                    build_pages( page_name ) do |vars|
                        ## Extension and Path
                        vars[:page].add_ext( tpl_ext )
                        vars[:template] = path
                        vars[:output] = output
                        eid = ( vars[:entry] && vars[:entry].id ) || page_name
                        if not @output_entry_map[ eid ]
                            @output_entry_map[ eid ] = vars
                        elsif tpl_ext.split( '.' )[1] == central_ext
                            @output_entry_map[ eid ] = vars
                        end

                        ## If output by a deeper page, skip
                        pub_name, = path_watch[vars[:page].link]
                        next if pub_name and !( vars[:page].link.index( page_name ) == 0 and
                                              page_name.length > pub_name.length )

                        path_watch[vars[:page].link] = [page_name, vars]
                    end
                end
            end
        end
        @output_map = {}
        path_watch.each_value do |page_name, vars|
            @output_map[page_name] ||= []
            @output_map[page_name] << vars
        end
        @output_map
    end

    # Built from the map of output destinations described by +output_map+, this map pairs
    # entry IDs against their canonical destinations.  The @central_prefix and @central_ext
    # variables determine what output is canonical.
    def output_entry_map
        output_map
        @output_entry_map
    end

    # Regenerates the weblog, processing templates in +skel_path+
    # with the data found in +entry_path+, storing output in
    # +output_path+.
    #
    # The _how_ parameter dictates how this is done,
    # Currently, if _how_ is nil the weblog is completely regen'd.
    # If it is :update, the weblog is only upgen'd.
    #
    # == How Updates Work
    #
    # It's very important to know how updates work, especially if
    # you are writing custom skel methods or devious new kinds of
    # templates.  When performing an update, this method will skip
    # pages if the following conditions are met:
    #
    # 1. The Page object for a given output page must have its
    #    +updated+ timestamp set.
    # 2. The output file pointed to by the Page object must
    #    already exist.
    # 3. The +updated+ timestamp must be older than than the
    #    modification time of the output file.
    # 4. The modification time of the input template must be older 
    #    than than the modification time of the output file.
    #
    # To ensure that your custom methods and templates are qualifying
    # to be skipped on an upgen, be sure to set the +updated+ timestamp
    # of the Page object to the latest date of the content's modification.
    #
    def regenerate( how = nil )
        retouch nil, how
    end
    def retouch( only_path = nil, how = nil )
        published = {}
        published_types = []
        output_map.each do |page_name, outputs|
            puts "[Building #{ page_name } pages]"
            outputs.each do |vars|
                full_out_path = File.join( output_path, vars[:page].link.split( '/' ) )
                ## If retouching, skip pages outside of path
                next if only_path and vars[:page].link.index( "/" + only_path ) != 0

                ## If updating, skip any that are unchanged
                next if how == :update and 
                        File.exists?( full_out_path ) and
                        File.mtime( vars[:template] ) < File.mtime( full_out_path ) and
                        ( vars[:page].updated.nil? or 
                          vars[:page].updated < File.mtime( full_out_path ) )

                p_publish vars[:page]
                vars.keys.each do |var_name|
                    case var_name.to_s
                    when /entry$/
                        unless vars[:no_load]
                            vars[var_name] = load_and_validate_entry( vars[var_name].id )
                        end
                    when /entries$/
                        unless vars[:no_load]
                            vars[var_name].collect! do |e|
                                load_and_validate_entry( e.id )
                            end
                        end
                        vars[var_name].extend Hobix::EntryEnum
                    end
                end

                ## Publish the page
                vars = vars.dup
                output = vars.delete( :output )
                template = vars.delete( :template )
                txt = output.load( template, vars )
                ## A plugin perhaps needs to change the output page name
                full_out_path = File.join( output_path, vars[:page].link.split( '/' ) )
                saved_umask = File.umask( 0002 ) rescue nil
                begin
                  File.makedirs( File.dirname( full_out_path ) )
                  File.open( full_out_path, 'w' ) do |f| 
                      f << txt
                  end
                ensure
                  File.umask( saved_umask ) rescue nil
                end
                published[vars[:page].link] = vars[:page]
                published_types << page_name
            end
        end
        published_types.uniq!
        publishers.each do |p|
            if p.respond_to? :watch
                if p.watch & published_types != []
                    p.publish( published )
                end
            else
                p.publish( published )
            end
        end

        commit_to_git if @git

        reset_output_map
    end

    # Method to commit to the local git repo and push pure happiness to the
    # remote server named blahg (which should be of webserving character and
    # a pleasant demeanor).
    def commit_to_git
      puts `git add .`
      puts `git commit -a -m "New poshts for the syhtt"`
      puts `git push blahg master`
    end

    # Handler for templates with `index' prefix.  These templates will
    # receive entries loaded by +Hobix::BaseStorage#lastn+.  Only one
    # index page is requested by this handler.
    def skel_index( path_storage, section_path )
        index_entries = path_storage.lastn( @lastn )
        page = Page.new( 'index', section_path )
        page.prev = index_entries.last.created.strftime( "%Y/%m/index" )
        page.timestamp = index_entries.first.created
        page.updated = path_storage.last_updated( index_entries )
        yield :page => page, :entries => index_entries
    end

    # Handler for templates with `daily' prefix.  These templates will
    # receive a list of entries for each day that has at least one entry
    # created in its time period.  This handler requests daily pages
    # to be output as `/%Y/%m/%d.ext'.
    def skel_daily( path_storage, section_path )
        entry_range = path_storage.find
        first_time, last_time = entry_range.last.created, entry_range.first.created
        start = Time.mktime( first_time.year, first_time.month, first_time.day, 0, 0, 0 ) + 1
        stop = Time.mktime( last_time.year, last_time.month, last_time.day, 23, 59, 59 )
        days = []
        one_day = 24 * 60 * 60
        until start > stop
            day_entries = path_storage.within( start, start + one_day - 1 )
            days << [day_entries.last.created, day_entries] unless day_entries.empty?
            start += one_day
        end
        days.extend Hobix::Enumerable
        days.each_with_neighbors do |prev, curr, nextd| 
            page = Page.new( curr[0].strftime( "%Y/%m/%d" ), section_path )
            page.prev = prev[0].strftime( "%Y/%m/%d" ) if prev
            page.next = nextd[0].strftime( "%Y/%m/%d" ) if nextd
            page.timestamp = curr[0]
            page.updated = path_storage.last_updated( curr[1] )
            yield :page => page, :entries => curr[1]
        end
    end

    # Handler for templates with `monthly' prefix.  These templates will
    # receive a list of entries for each month that has at least one entry
    # created in its time period.  This handler requests monthly pages
    # to be output as `/%Y/%m/index.ext'.
    def skel_monthly( path_storage, section_path )
        months = path_storage.get_months( path_storage.find )
        months.extend Hobix::Enumerable
        months.each_with_neighbors do |prev, curr, nextm| 
            entries = path_storage.within( curr[0], curr[1] )
            page = Page.new( curr[0].strftime( "%Y/%m/index" ), section_path )
            page.prev = prev[0].strftime( "%Y/%m/index" ) if prev
            page.next = nextm[0].strftime( "%Y/%m/index" ) if nextm
            page.timestamp = curr[1]
            page.updated = path_storage.last_updated( entries )
            yield :page => page, :entries => entries
        end
    end

    # Handler for templates with `yearly' prefix.  These templates will
    # receive a list of entries for each month that has at least one entry
    # created in its time period.  This handler requests yearly pages
    # to be output as `/%Y/index.ext'.
    def skel_yearly( path_storage, section_path )
        entry_range = path_storage.find
        first_time, last_time = entry_range.last.created, entry_range.first.created
        years = (first_time.year..last_time.year).collect do |y|
            [ Time.mktime( y, 1, 1 ), Time.mktime( y + 1, 1, 1 ) - 1 ]
        end
        years.extend Hobix::Enumerable
        years.each_with_neighbors do |prev, curr, nextm| 
            entries = path_storage.within( curr[0], curr[1] )
            page = Page.new( curr[0].strftime( "%Y/index" ), section_path )
            page.prev = prev[0].strftime( "%Y/index" ) if prev
            page.next = nextm[0].strftime( "%Y/index" ) if nextm
            page.timestamp = curr[1]
            page.updated = path_storage.last_updated( entries )
            yield :page => page, :entries => entries
        end
    end

    # Handler for templates with `entry' prefix.  These templates will
    # receive one entry for each entry in the weblog.  The handler requests
    # entry pages to be output as `/shortName.ext'.
    def skel_entry( path_storage, section_path )
        all_entries = [path_storage.find]
        all_entries += sections_ignored.collect { |ign| path_storage.find( :all => true, :inpath => ign ) }
        all_entries.each do |entry_set|
            entry_set.extend Hobix::Enumerable
            entry_set.each_with_neighbors do |nexte, entry, prev|
                page = Page.new( entry.id )
                page.prev = prev.id if prev
                page.next = nexte.id if nexte
                page.timestamp = entry.created
                page.updated = path_storage.updated( entry.id )
                yield :page => page, :entry => entry
            end
        end
    end

    # Handler for templates with `section' prefix.  These templates
    # will receive all entries below a given directory.  The handler
    # requests will be output as `/section/index.ext'.
    def skel_section( path_storage, section_path )
        section_map = {}
        path_storage.all.each do |entry|
            dirs = entry.id.split( '/' )
            while ( dirs.pop; dirs.first )
                section = dirs.join( '/' )
                section_map[ section ] ||= []
                section_map[ section ] << entry
            end
        end
        section_map.each do |section, entries|
            page = Page.new( "/#{ section }/index" )
            page.updated = path_storage.last_updated( entries )
            yield :page => page, :entries => entries
        end
    end

    # Receive a Hash pairing all section ids with the options for that section.
    def sections( opts = nil )
        sections = Marshal::load( Marshal::dump( @sections ) )
        observes = !sections.values.detect { |s| s['observe'] }
        storage.sections.each do |s|
            sections[s] ||= {}
            sections[s]['observe'] ||= sections[s].has_key?( 'ignore' ) ? !sections[s]['ignore'] : observes
            sections[s]['ignore'] ||= !sections[s]['observe']
        end
        sections
    end

    # Returns a hash of special sorting cases.  Key is the entry path,
    # value is the sorting method.  Storage plugins must honor these
    # default sorts.
    def sections_sorts
        @sections.inject( {} ) do |sorts, set|
            k, v = set
            sorts[k] = v['sort_by'] if v['sort_by']
            sorts
        end
    end

    # Returns an Array of entry paths ignored by general querying.
    # Storage plugins must withhold these entries from queries, unless
    # the :all => true setting is passed to the query.
    def sections_ignored
        sections.collect do |k, v|
            k if v['ignore']
        end.compact
    end

    # Handler for templates with `tags' prefix.  These templates
    # will receive a tag with all entries tagged with it. The handler
    # requests will be output as `/tags/<tag>/index.ext'.
    def skel_tags( path_storage, section_path ) 
      # Get a list of all known tags
      tags = path_storage.find( :all => true ).map { |e| e.tags }.flatten.uniq
      
      tags.each do |tag|
        entries = path_storage.find.find_all { |e| e.tags.member? tag }
        page = Page.new( File::join( 'tags',tag,'index' ), section_path )
        page.updated = path_storage.last_updated( entries ) 
        yield :page => page, :entries => entries
      end
    end

    def join_path( prefix, suffix )
        case prefix
	when '', '.'
            suffix
	else
            "#{ prefix }/#{ suffix }"
	end
    end

    class AuthorNotFound < Exception; end

    # Loads an entry from +storage+, first validating that the author
    # is listed in the weblog config.
    def load_and_validate_entry( entry_id )
        entry = storage.load_entry( entry_id )
        unless authors.has_key?( entry.author )
            raise AuthorNotFound, "Invalid author '#{ entry.author }' found in entry #{ entry_id }"
        end
        entry
    end

    def authorize( user, pass )
        require 'digest/sha1'
        authors[user]['password'] == Digest::SHA1.new( pass )
    end

    # For convenience, storage queries can be made through the Weblog
    # class.  Queries will return the full Entry data, though, so it's
    # best to use this only when you're scripting and need data quick.
    def method_missing( methId, *args )
        if storage.respond_to? methId
            storage.method( methId ).call( *args ).collect do |e|
                load_and_validate_entry( e.id )
            end
        end
    end

    # Prints publication information the screen.  Override this if
    # you want to suppress output or change the display.
    def p_publish( obj )
        puts "## Page: #{ obj.link }, updated #{ obj.updated }"
    end

    ## YAML Display

    # Returns the YAML type information, which expands to
    # tag:hobix.com,2004:weblog.
    def to_yaml_type
        "!hobix.com,2004/weblog"
    end

end
end

YAML::add_domain_type( 'hobix.com,2004', 'weblog' ) do |type, val|
    YAML::object_maker( Hobix::Weblog, val )
end

YAML::add_domain_type( 'hobix.com,2004', 'bixwik' ) do |type, val|
    require 'hobix/bixwik'
    YAML::object_maker( Hobix::BixWik, val )
end
