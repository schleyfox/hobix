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
require 'find'
require 'ftools'
require 'yaml'

module Hobix
class Page
    attr_accessor :link, :next, :prev, :timestamp, :updated
    def initialize( link )
        @link = link
    end
    def add_ext( ext )
        @link += ext if @link
        @next += ext if @next
        @prev += ext if @prev
    end
end
class Weblog
    attr_accessor :title, :link, :authors, :contributors, :tagline,
                  :copyright, :period, :path, :sections, :requires,
                  :entry_path, :skel_path, :output_path, :lib_path

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

    # Load the weblog information from a YAML file.
    def Weblog::load( file )
        weblog = YAML::load( File::open( file ) )
        weblog.start( File.dirname( file ) )
        weblog
    end

    def build_pages( page_name )
        puts "Building #{ page_name } pages..."
        vars = {}
        if respond_to? "skel_#{ page_name }"
            method( "skel_#{ page_name }" ).call( page_name ) do |vars|
                vars[:weblog] = self
                yield vars
            end
        else
            vars[:weblog] = self
            vars[:page] = Page.new( "/" + page_name )
            vars[:page].timestamp = Time.now
            yield vars
        end
    end

    def storage
        @plugins.detect { |p| p.is_a? BaseStorage }
    end

    def regenerate( how = nil )
        outputs = @plugins.find_all { |p| p.is_a? BaseOutput }
        Find::find( @skel_path ) do |path|
            if FileTest.directory? path
                Find.prune if File.basename(path)[0] == ?.
            else
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
                                vars[:page].updated < File.mtime( full_entry_path )
                        p vars[:page]
                        if vars[:entry]
                            vars[:entry] = storage.load_entry( vars[:entry] )
                        elsif vars[:entries]
                            vars[:entries].collect! do |e|
                                storage.load_entry( e[0] )
                            end
                        end
                        html = output.load( path, vars )
                        File.makedirs( File.join( @output_path, File.dirname( entry_path ) ) )
                        File.open( File.join( @output_path, entry_path ), 'w' ) { |f| f << html } unless html.empty?
                    end
                else
                    full_entry_path = File.join( @output_path, entry_path )
                    next if File.mtime( full_entry_path ) >= File.mtime( path )
                    File.makedirs( File.dirname( full_entry_path ) )
                    File.copy( path, full_entry_path )
                end
            end
        end
    end

    def skel_index( page_name )
        index_entries = storage.lastn
        page = Page.new( 'index' )
        page.prev = index_entries.last[1].strftime( "/%Y/%m/index" )
        page.timestamp = index_entries.first[1]
        page.updated = storage.last_modified( index_entries )
        yield :page => page, :entries => index_entries
    end

    def skel_daily( page_name )
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
            page = Page.new( curr[0].strftime( "/%Y/%m/%d" ) )
            page.prev = prev[0].strftime( "/%Y/%m/%d" ) if prev
            page.next = nextd[0].strftime( "/%Y/%m/%d" ) if nextd
            page.timestamp = curr[0]
            page.updated = storage.last_modified( curr[1] )
            yield :page => page, :entries => curr[1]
        end
    end

    def skel_monthly( page_name )
        entry_range = storage.find
        first_time, last_time = entry_range.last[1], entry_range.first[1]
        start = Time.mktime( first_time.year, first_time.month, 1 )
        stop = Time.mktime( last_time.year, last_time.month, last_time.day )
        months = []
        until start > stop
            next_year, next_month = start.year, start.month + 1
            if next_month > 12
                next_year += next_month / 12
                next_month %= 12
            end
            month_end = Time.mktime( next_year, next_month, 1 ) - 1
            months << [ start, month_end ]
            start = month_end + 1
        end
        months.extend Hobix::Enumerable
        months.each_with_neighbors do |prev, curr, nextm| 
            entries = storage.within( curr[0], curr[1] )
            page = Page.new( curr[0].strftime( "/%Y/%m/index" ) )
            page.prev = prev[0].strftime( "/%Y/%m/index" ) if prev
            page.next = nextm[0].strftime( "/%Y/%m/index" ) if nextm
            page.timestamp = curr[1]
            page.updated = storage.last_modified( entries )
            yield :page => page, :entries => entries
        end
    end

    def sections_sorts
        @sections.inject( {} ) do |sorts, set|
            k, v = set
            sorts[k] = v['sort_by'] if v['sort_by']
            sorts
        end
    end

    def sections_ignored
        @sections.collect do |k, v|
            k if v['ignore']
        end.compact
    end

    def skel_entry( page_name )
        all_entries = [storage.all]
        all_entries += sections_ignored.collect { |ign| storage.find( :all => true, :inpath => ign ) }
        all_entries.each do |entry_set|
            entry_set.extend Hobix::Enumerable
            entry_set.each_with_neighbors do |nexte, entry, prev|
                page = Page.new( "/" + entry[0] )
                page.prev = "/" + prev[0] if prev
                page.next = "/" + nexte[0] if nexte
                page.timestamp = entry[1]
                page.updated = storage.modified( entry[0] )
                yield :page => page, :entry => entry[0]
            end
        end
    end

    def method_missing( methId, *args )
        if storage.respond_to? methId
            storage.method( methId ).call( *args ).collect do |e|
                storage.load_entry( e[0] )
            end
        end
    end
end
end

YAML::add_domain_type( 'hobix.com,2004', 'weblog' ) do |type, val|
    YAML::object_maker( Hobix::Weblog, val )
end
