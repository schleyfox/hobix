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
    attr_accessor :link, :next, :prev, :timestamp
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
                  :copyright, :period, :path, :ignore, :requires,
                  :entry_path, :skel_path, :output_path

    def start( path )
        @path = path
        @ignore ||= []
        @entry_path ||= "entries"
        @entry_path = File.join( path, @entry_path ) if @entry_path !~ /^\//
        @skel_path ||= "skel"
        @skel_path = File.join( path, @skel_path ) if @skel_path !~ /^\//
        @output_path ||= "htdocs"
        @output_path = File.join( path, @output_path ) if @output_path !~ /^\//
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

    def build_pages( page_name, how )
        vars = { :weblog => self }
        case page_name
        when 'index'
            index_entries = storage.lastn
            vars[:page] = Page.new( 'index' )
            vars[:page].prev = index_entries.last[1].strftime( "/%Y/%m/index" )
            vars[:page].timestamp = index_entries.first[1]
            vars[:entries] = index_entries.collect { |e| storage.load_entry( e[0] ) }
            p vars[:page]
            yield vars
        when 'monthly'
            entry_range = storage.find
            first_time, last_time = entry_range.last[1], entry_range.first[1]
            start = Time.local( first_time.year, first_time.month, 1 )
            stop = Time.local( last_time.year, last_time.month, last_time.day )
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
                vars[:page] = Page.new( curr[0].strftime( "/%Y/%m/index" ) )
                vars[:page].prev = prev[0].strftime( "/%Y/%m/index" ) if prev
                vars[:page].next = nextm[0].strftime( "/%Y/%m/index" ) if nextm
                vars[:page].timestamp = curr[1]
                vars[:entries] = storage.within( curr[0], curr[1] ).
                        collect { |e| storage.load_entry( e[0] ) }
                p vars[:page]
                yield vars
            end
        when 'entry'
            all_entries = [storage.all]
            all_entries += @ignore.collect { |ign| storage.find( :all => true, :inpath => ign ) }
            all_entries.each do |entry_set|
                entry_set.extend Hobix::Enumerable
                entry_set.each_with_neighbors do |nexte, entry, prev|
                    vars[:page] = Page.new( "/" + entry[0] )
                    vars[:page].prev = "/" + prev[0] if prev
                    vars[:page].next = "/" + nexte[0] if nexte
                    vars[:page].timestamp = entry[1]
                    vars[:entry] = storage.load_entry( entry[0] )
                    p vars[:page]
                    yield vars
                end
            end
        else
            vars[:page] = Page.new( "/" + page_name )
            vars[:page].timestamp = Time.now
            p vars[:page]
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
                    page_name, entry_ext = entry_path.dup, ''
                    while page_name =~ /\.\w+$/; page_name = $`; entry_ext = $& + entry_ext; end
                    next if entry_ext.empty?
                    build_pages( page_name, how ) do |vars|
                        vars[:page].add_ext( entry_ext )
                        html = output.load( path, vars )
                        entry_path = vars[:page].link
                        File.makedirs( File.join( @output_path, File.dirname( entry_path ) ) )
                        File.open( File.join( @output_path, entry_path ), 'w' ) { |f| f << html } unless html.empty?
                    end
                else
                    File.makedirs( File.join( @output_path, File.dirname( entry_path ) ) )
                    File.copy( path, File.join( @output_path, entry_path ) )
                end
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
