#
# = hobix/weblog.rb
#
# Hobix command-line weblog system.
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
require 'hobix/entry'
require 'hobix/linklist'
require 'find'
require 'ftools'
require 'yaml'

module Hobix
#
# The Page class is very simple class which contains information
# specific to a template.
#
# == Introduction
#
# The +link+, +next+ and +prev+ accessors
# provide complete URLs for the current page and its neighbors
# (for example, in the case of monthly archives, which may have
# surrounding months.)
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
#   <% if page.prev %>"last":<%= page.prev %><% end %>
#   <% if page.next %>"next":<%= page.next %><% end %>
#
class Page
    attr_accessor :link, :next, :prev, :timestamp, :updated
    def initialize( link )
        @link = link
    end
    def add_dir( dir ) #:nodoc:
        @link = File.join( dir, @link ) if @link
        @next = File.join( dir, @next ) if @next
        @prev = File.join( dir, @prev ) if @prev
    end
    def add_ext( ext ) #:nodoc:
        @link += ext if @link
        @next += ext if @next
        @prev += ext if @prev
    end
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
# link::           The absolute url to the weblog.
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
#   def skel_index
#       index_entries = storage.lastn
#       page = Page.new( 'index' )
#       page.prev = index_entries.last[1].strftime( "/%Y/%m/index" )
#       page.timestamp = index_entries.first[1]
#       page.updated = storage.last_modified( index_entries )
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
#       def skel_sidebar
#           ## Load `about' and `learn' entries
#           abouts = storage.find( :all => true, :inpath => 'about' ).reverse
#           learns = storage.find( :all => true, :inpath => 'learn' ).reverse
#   
#           ## Create page data
#           page = Page.new( 'sidebar' )
#           page.updated = storage.last_modified( abouts + learns )
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
# to +Hobix::BaseStorage#last_modified+.  The +updated+ property is being
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
class Weblog
    attr_accessor :title, :link, :authors, :contributors, :tagline,
                  :copyright, :period, :path, :sections, :requires,
                  :entry_path, :skel_path, :output_path, :lib_path

    # After the weblog is initialize, the +start+ method is called
    # with the full system path to the directory containing the configuration.
    #
    # This method sets up all the paths and loads the plugins.
    def start( path )
        @path = path
        @sections ||= {}
        @entry_path ||= "entries"
        @entry_path = File.join( path, @entry_path ) if @entry_path !~ /^\//
        @skel_path ||= "skel"
        @skel_path = File.join( path, @skel_path ) if @skel_path !~ /^\//
        @output_path ||= "htdocs"
        @output_path = File.join( path, @output_path ) if @output_path !~ /^\//
        @lib_path ||= "lib"
        @lib_path = File.join( path, @lib_path ) if @lib_path !~ /^\//
        if File.exists?( @lib_path )
            $LOAD_PATH << @lib_path
        end
        @plugins = []
        @requires.each do |req|
            @plugins += Hobix::BasePlugin::start( req, self )
        end
    end

    # Load the weblog information from a YAML file and +start+ the Weblog.
    def Weblog::load( file )
        weblog = YAML::load( File::open( file ) )
        weblog.start( File.dirname( file ) )
        weblog
    end

    # Used by +regenerate+ to construct the vars hash by calling
    # the appropriate skel method for each page.
    def build_pages( page_name )
        puts "[Building #{ page_name } pages]"
        vars = {}
        paths = File.split( page_name )
        page_dir = File.dirname( page_name )
        loop do
            try_page = paths.join( '_' )
            if respond_to? "skel_#{ try_page }"
                method( "skel_#{ try_page }" ).call do |vars|
                    vars[:weblog] = self
                    raise TypeError, "No `page' variable returned from skel_#{ try_page }." unless vars[:page]
                    vars[:page].add_dir( "/#{ page_dir if page_dir != '.' }" )
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
        published = []
        Find::find( @skel_path ) do |path|
            if File.basename(path)[0] == ?.
                Find.prune 
            elsif not FileTest.directory? path
                entry_path = path.gsub( /^#{ Regexp::quote( @skel_path ) }\/?/, '' )
                output = outputs.detect { |p| if entry_path =~ /\.#{ p.extension }$/; entry_path = $`; end }
                if output
                    ## Figure out template extension and output filename
                    page_name, entry_ext = entry_path.dup, ''
                    while page_name =~ /\.\w+$/; page_name = $`; entry_ext = $& + entry_ext; end
                    next if entry_ext.empty?
                    ## Build the output pages
                    build_pages( page_name ) do |vars|
                        ## Extension and Path
                        vars[:page].add_ext( entry_ext )
                        entry_path = vars[:page].link
                        full_entry_path = File.join( @output_path, entry_path )

                        ## If updating, skip any that are unchanged
                        next if how == :update and vars[:page].updated != nil and 
                                File.exists?( full_entry_path ) and
                                File.mtime( path ) < File.mtime( full_entry_path ) and
                                vars[:page].updated < File.mtime( full_entry_path )
                        p_publish vars[:page]
                        vars.keys.each do |var_name|
                            case var_name.to_s
                            when /entry$/
                                vars[var_name] = storage.load_entry( vars[var_name] )
                            when /entries$/
                                vars[var_name].collect! do |e|
                                    storage.load_entry( e[0] )
                                end
                                vars[var_name].extend Hobix::EntryEnum
                            end
                        end

                        ## Publish the page
                        txt = output.load( path, vars )
                        File.makedirs( File.join( @output_path, File.dirname( entry_path ) ) )
                        File.open( full_entry_path, 'w' ) { |f| f << txt }
                        published << page_name
                    end
                else
                    full_entry_path = File.join( @output_path, entry_path )
                    next if File.mtime( full_entry_path ) >= File.mtime( path )
                    File.makedirs( File.dirname( full_entry_path ) )
                    File.copy( path, full_entry_path )
                end
            end
        end
        published.uniq!
        publishers.each do |p|
            if p.watch & published != []
                p.publish( p )
            end
        end
    end

    # Handler for templates with `index' prefix.  These templates will
    # receive entries loaded by +Hobix::BaseStorage#lastn+.  Only one
    # index page is requested by this handler.
    def skel_index
        index_entries = storage.lastn
        page = Page.new( 'index' )
        page.prev = index_entries.last[1].strftime( "%Y/%m/index" )
        page.timestamp = index_entries.first[1]
        page.updated = storage.last_modified( index_entries )
        yield :page => page, :entries => index_entries
    end

    # Handler for templates with `daily' prefix.  These templates will
    # receive a list of entries for each day that has at least one entry
    # created in its time period.  This handler requests daily pages
    # to be output as `/%Y/%m/%d.ext'.
    def skel_daily
        entry_range = storage.find
        first_time, last_time = entry_range.last[1], entry_range.first[1]
        start = Time.mktime( first_time.year, first_time.month, first_time.day, 0, 0, 0 ) + 1
        stop = Time.mktime( last_time.year, last_time.month, last_time.day, 23, 59, 59 )
        days = []
        one_day = 24 * 60 * 60
        until start > stop
            day_entries = storage.within( start, start + one_day - 1 )
            days << [day_entries.last[1], day_entries] unless day_entries.empty?
            start += one_day
        end
        days.extend Hobix::Enumerable
        days.each_with_neighbors do |prev, curr, nextd| 
            page = Page.new( curr[0].strftime( "%Y/%m/%d" ) )
            page.prev = prev[0].strftime( "%Y/%m/%d" ) if prev
            page.next = nextd[0].strftime( "%Y/%m/%d" ) if nextd
            page.timestamp = curr[0]
            page.updated = storage.last_modified( curr[1] )
            yield :page => page, :entries => curr[1]
        end
    end

    # Handler for templates with `monthly' prefix.  These templates will
    # receive a list of entries for each month that has at least one entry
    # created in its time period.  This handler requests monthly pages
    # to be output as `/%Y/%m/index.ext'.
    def skel_monthly
        months = storage.get_months( storage.find )
        months.extend Hobix::Enumerable
        months.each_with_neighbors do |prev, curr, nextm| 
            entries = storage.within( curr[0], curr[1] )
            page = Page.new( curr[0].strftime( "%Y/%m/index" ) )
            page.prev = prev[0].strftime( "%Y/%m/index" ) if prev
            page.next = nextm[0].strftime( "%Y/%m/index" ) if nextm
            page.timestamp = curr[1]
            page.updated = storage.last_modified( entries )
            yield :page => page, :entries => entries
        end
    end

    # Handler for templates with `yearly' prefix.  These templates will
    # receive a list of entries for each month that has at least one entry
    # created in its time period.  This handler requests yearly pages
    # to be output as `/%Y/index.ext'.
    def skel_yearly
        entry_range = storage.find
        first_time, last_time = entry_range.last[1], entry_range.first[1]
        years = (first_time.year..last_time.year).collect do |y|
            [ Time.mktime( y, 1, 1 ), Time.mktime( y + 1, 1, 1 ) - 1 ]
        end
        years.extend Hobix::Enumerable
        years.each_with_neighbors do |prev, curr, nextm| 
            entries = storage.within( curr[0], curr[1] )
            page = Page.new( curr[0].strftime( "%Y/index" ) )
            page.prev = prev[0].strftime( "%Y/index" ) if prev
            page.next = nextm[0].strftime( "%Y/index" ) if nextm
            page.timestamp = curr[1]
            page.updated = storage.last_modified( entries )
            yield :page => page, :entries => entries
        end
    end

    # Handler for templates with `entry' prefix.  These templates will
    # receive one entry for each entry in the weblog.  The handler requests
    # entry pages to be output as `/shortName.ext'.
    def skel_entry
        all_entries = [storage.find]
        all_entries += sections_ignored.collect { |ign| storage.find( :all => true, :inpath => ign ) }
        all_entries.each do |entry_set|
            entry_set.extend Hobix::Enumerable
            entry_set.each_with_neighbors do |nexte, entry, prev|
                page = Page.new( entry[0] )
                page.prev = prev[0] if prev
                page.next = nexte[0] if nexte
                page.timestamp = entry[1]
                page.updated = storage.modified( entry[0] )
                yield :page => page, :entry => entry[0]
            end
        end
    end

    # Handler for templates with `section' prefix.  These templates
    # will receive all entries below a given directory.  The handler
    # requests will be output as `/section/index.ext'.
    def skel_section
        section_map = {}
        storage.all.each do |entry|
            dirs = entry[0].split( '/' )
            while ( dirs.pop; dirs.first )
                section = dirs.join( '/' )
                section_map[ section ] ||= []
                section_map[ section ] << entry
            end
        end
        section_map.each do |section, entries|
            page = Page.new( section + "/index" )
            page.updated = storage.last_modified( entries )
            yield :page => page, :entries => entries
        end
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
        @sections.collect do |k, v|
            k if v['ignore']
        end.compact
    end

    # For convenience, storage queries can be made through the Weblog
    # class.  Queries will return the full Entry data, though, so it's
    # best to use this only when you're scripting and need data quick.
    def method_missing( methId, *args )
        if storage.respond_to? methId
            storage.method( methId ).call( *args ).collect do |e|
                storage.load_entry( e[0] )
            end
        end
    end

    # Prints publication information the screen.  Override this if
    # you want to suppress output or change the display.
    def p_publish( obj )
        puts "## Page: #{ obj.link }, updated #{ obj.updated }"
    end

    ## YAML Display
    include ToYamlExtras
    def to_yaml_property_map
        [
            ['@title', :req], 
            ['@link', :req], 
            ['@tagline', :req], 
            ['@period', :opt], 
            ['@entry_path', :opt],
            ['@skel_path', :opt],
            ['@output_path', :opt],
            ['@authors', :req], 
            ['@contributors', :opt], 
            ['@sections', :opt], 
            ['@requires', :req]
        ]
    end

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
