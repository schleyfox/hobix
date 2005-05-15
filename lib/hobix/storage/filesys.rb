#
# = hobix/storage/filesys.rb
#
# Hobix command-line weblog system.
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
require 'find'
require 'yaml'

module Hobix
module Storage
class IndexEntry
    def self.fields; @fields; end
    def self.add_fields( *names )
        @fields ||= []
        @fields += names
        attr_accessor *names
    end

    add_fields :id, :created, :modified, :tags

    def initialize( entry, fields = IndexEntry.fields )
        fields.each do |field|
            val = if entry.respond_to? field
                      entry.send( field )
                  elsif respond_to? "make_#{field}"
                      send( "make_#{field}", entry )
                  else
                      :unset
                  end
            send( "#{field}=", val )
        end

        yield self if block_given?
    end

    def to_yaml_type
        "!hobix.com,2004/storage/indexEntry"
    end

end

YAML::add_domain_type( 'hobix.com,2004', 'storage/indexEntry' ) do |type, val|
    YAML::object_maker( IndexEntry, val )
end

class FileSys < Hobix::BaseStorage
    def initialize( weblog )
        @modified = {}
        @basepath = weblog.entry_path
        @link = weblog.link
        @default_author = weblog.authors.keys.first
        ignored = weblog.sections_ignored
        unless ignored.empty?
            @ignore_test = /^(#{ ignored.collect { |i| Regexp.quote( i ) }.join( '|' ) })/
        end
        @sorts = weblog.sections_sorts
    end
    def now; Time.at( Time.now.to_i ); end
    def extension
        'yaml'
    end
    def check_id( id )
        id.untaint if id.tainted? and id =~ /^[\w\/\\]+$/
    end
    def entry_path( id, ext = extension )
        File.join( @basepath, id.split( '/' ) ) + "." + ext
    end
    def save_entry( id, e )
        load_index
        check_id( id )
        e.created ||= (@index.has_key?( id ) ? @index[id].created : now)
        path = entry_path( id )
        YAML::dump( e, File.open( path, 'w' ) )

        @entry_cache ||= {}
        e.id = id
        e.link = "#{ @link }/#{ id }.html"
        e.modified = now
        @entry_cache[id] = e

        @index[id] = IndexEntry.new( e ) do |i|
            i.modified = e.modified
        end
        @modified[id] = e.modified
        sort_index
        e
    end
    def load_entry( id )
        return default_entry( @default_author ) if id == default_entry_id
        load_index
        check_id( id )
        @entry_cache ||= {}
        unless @entry_cache.has_key? id
            entry_file = entry_path( id )
            e = Hobix::Entry::load( entry_file )
            e.id = id
            e.link = "#{ @link }/#{ id }.html"
            e.modified = modified( id )
            unless e.created
                e.created = @index[id].created
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

        index_fields = IndexEntry.fields
        Find::find( @basepath ) do |path|
            path.untaint
            if FileTest.directory? path
                Find.prune if File.basename(path)[0] == ?.
            else
                entry_path = path.gsub( /^#{ Regexp::quote( @basepath ) }\/?/, '' )
                next if entry_path !~ /\.#{ Regexp::quote( extension ) }$/
                entry_paths = File.split( $` )
                entry_paths.shift if entry_paths.first == '.'
                entry_id = entry_paths.join( '/' )
                @modified[entry_id] = File.mtime( path )


                index_entry = nil
                if ( index.has_key? entry_id ) and !( index[entry_id].is_a? ::Time ) # old index format
                    index_entry = index[entry_id]
                end
                ## we will (re)load the entry if:
                if index_entry.nil? or # it's new
                        ( index_entry.modified != @modified[entry_id] ) or # it's changed
                        index_fields.detect { |f| index_entry.send( f ).nil? } # index fields have been added

                    efile = entry_path( entry_id )
                    e = Hobix::Entry::load( efile )
                    e.id = entry_id
                    index_entry = IndexEntry.new( e, index_fields ) do |i|
                        i.id = entry_id
                        i.modified = @modified[entry_id]
                    end
                end
                @index[index_entry.id] = index_entry
            end
        end
        sort_index
        true
    end
    def sort_index
        return unless @index
        index_path = File.join( @basepath, 'index.hobix' )
        @index.sort! { |x,y| y[1].created <=> x[1].created }
        File.open( index_path, 'w' ) do |f|
            YAML::dump( @index, f )
        end
    end
    def path_storage( p )
        return self if ['', '.'].include? p
        load_index
        path_storage = self.dup
        path_storage.instance_eval do
            @index = @index.dup.delete_if do |id, entry|
                if id.index( p ) != 0
                    @modified.delete( p )
                    true
                end
            end
        end
        path_storage
    end
    def find( search = {} )
        load_index
        _index = @index
        if _index.empty?
            e = default_entry( @default_author )
            e.id = default_entry_id 
            @modified[e.id] = e.modified
            _index = {e.id => IndexEntry.new(e)}
        end
        entries = _index.collect do |id, entry|
                      skip = false
                      if @ignore_test and not search[:all]
                          skip = entry.id =~ @ignore_test
                      end
                      search.each do |skey, sval|
                          break if skip
                          skip = case skey
                                 when :after
                                     entry.created < sval
                                 when :before
                                     entry.created > sval
                                 when :inpath
                                     entry.id.index( sval ) != 0
                                 when :match
                                     entry.id.match sval
                                 else
                                     false
                                 end
                      end
                      if skip then nil else entry end
                  end.compact
        entries.slice!( search[:lastn]..-1 ) if search[:lastn] and entries.length > search[:lastn]
        entries
    end
    def last_modified( entries )
        entries.collect do |entry|
            @modified[entry.id]
        end.max
    end
    def last_created( entries )
        entries.collect do |entry|
            entry.created
        end.max
    end
    def modified( entry_id )
        @modified[entry_id]
    end
    def get_months( entries )
        return [] if entries.empty?
        first_time = entries.collect { |e| e.created }.min
        last_time = entries.collect { |e| e.created }.max
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

    # basic entry attachment functions
    def find_attached( id )
        check_id( id )
        Dir[ entry_path( id, '*' ) ].collect do |att|
            atp = att.match( /#{ Regexp::quote( id ) }\.(?!#{ extension }$)/ )
            atp.post_match if atp
        end.compact
    end
    def load_attached( id, ext )
        check_id( id )
        @attach_cache ||= {}
        file_id = "#{ id }.#{ ext }"
        unless @attach_cache.has_key? file_id
            @attach_cache[id] = File.open( entry_path( id, ext ) ) do |f| 
                YAML::load( f )
            end
        else
            @attach_cache[id]
        end
    end
    def save_attached( id, ext, e )
        check_id( id )
        File.open( entry_path( id, ext ), 'w' ) do |f|
            YAML::dump( e, f )
        end

        @attach_cache ||= {}
        @attach_cache[id] = e
    end
end
end
end
