#
# = hobix/storage/filesys.rb
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
require 'find'
require 'yaml'

module Hobix
module Storage
class FileSys < Hobix::BaseStorage
    def initialize( weblog )
        @modified = {}
        @basepath = weblog.entry_path
        @link = weblog.link
        ignored = weblog.sections_ignored
        unless ignored.empty?
            @ignore_test = /^(#{ ignored.collect { |i| Regexp.quote( i ) }.join( '|' ) })/
        end
        @sorts = weblog.sections_sorts
    end
    def extension
        'yaml'
    end
    def save_entry( id, e )
        entry_file = File.join( @basepath, id + "." + extension )
        e.created = Time.now
        YAML::dump( e, File.open( entry_file, 'w' ) )

        load_index
        @entry_cache ||= {}
        @entry_cache[id] = e
    end
    def load_entry( id )
        @entry_cache ||= {}
        unless @entry_cache.has_key? id
            entry_file = File.join( @basepath, id + "." + extension )
            e = Hobix::Entry::load( entry_file )
            e.id = id
            e.link = @link + id + ".html"
            unless e.created
                e.created = @index[id]
                YAML::dump( e, File.open( entry_file, 'w' ) )
            end
            @entry_cache[id] = e
        else
            @entry_cache[id]
        end
    end
    def load_index
        return false if @index
        index_path = File.join( @basepath, 'index.hobix' )
        index = if File.exists? index_path
                     YAML::load( File.open( index_path ) )
                 else
                     YAML::Omap::new
                 end
        @index = YAML::Omap::new
        Find::find( @basepath ) do |path|
            if FileTest.directory? path
                Find.prune if File.basename(path)[0] == ?.
            else
                entry_path = path.gsub( /^#{ Regexp::quote( @basepath ) }\/?/, '' )
                next if entry_path !~ /\.#{ Regexp::quote( extension ) }$/
                entry_id = $`
                @modified[entry_id] = File.mtime( path )
                unless index.has_key? entry_id
                    @index[entry_id] = @modified[entry_id]
                else
                    @index[entry_id] = index[entry_id]
                    index.delete( entry_id )
                end
            end
        end
        @index.sort! { |x,y| y[1] <=> x[1] }
        YAML::dump( @index, File.open( index_path, 'w' ) )
        true
    end
    def find( search = {} )
        load_index
        entries = @index.reject do |entry|
                      skip = false
                      if @ignore_test and not search[:all]
                          skip = entry[0] =~ @ignore_test
                      end
                      search.each do |skey, sval|
                          break if skip
                          skip = case skey
                                 when :after
                                     entry[1] < sval
                                 when :before
                                     entry[1] > sval
                                 when :inpath
                                     entry[0].index( sval ) != 0
                                 else
                                     false
                                 end
                      end
                      skip
                  end
        entries.slice!( search[:lastn]..-1 ) if search[:lastn] and entries.length > search[:lastn]
        entries
    end
    def last_modified( entries )
        entries.collect do |entry|
            @modified[entry[0]]
        end.max
    end
    def modified( entry_id )
        @modified[entry_id]
    end
    def get_months( entries )
        first_time = entries.collect { |e| e[1] }.min
        last_time = entries.collect { |e| e[1] }.max
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
            months << [ start, month_end, start.strftime( "/%Y/%m/" ) ]
            start = month_end + 1
        end
        months
    end
end
end
end
