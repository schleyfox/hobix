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
require 'fileutils'
# require 'hobix/search/simple'

module Hobix

#
# The IndexEntry class 
#
class IndexEntry < BaseContent
    def initialize( entry, fields = self.class.properties.keys )
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

    yaml_type "!hobix.com,2004/storage/indexEntry"
end

module Storage

#
# The FileSys class is a storage plugin, it manages the loading and dumping of
# Hobix entries and attachments.  The FileSys class also keeps an index of entry
# information, to keep the system from loading unneeded entries.
class FileSys < Hobix::BaseStorage
    # Start the storage plugin for the +weblog+ passed in.
    def initialize( weblog )
        super( weblog )
        @updated = {}
        @basepath = weblog.entry_path
        @default_author = weblog.authors.keys.first
        @weblog = weblog
    end

    def now; Time.at( Time.now.to_i ); end

    # The default extension for entries.  Defaults to: yaml.
    def extension
        'yaml'
    end

    # Determine if +id+ is a valid entry identifier, untaint if so.
    def check_id( id )
        id.untaint if id.tainted? and id =~ /^[\w\/\\]+$/
    end

    # Build an entry's complete path based on its +id+.  Optionally, extension +ext+ can
    # be used to find the path of attachments.
    def entry_path( id, ext = extension )
        File.join( @basepath, id.split( '/' ) ) + "." + ext
    end

    # Brings an entry's updated time current.
    def touch_entry( id )
        check_id( id )
        @updated[id] = Time.now
        FileUtils.touch entry_path( id )
    end

    # Save the entry object +e+ and identify it as +id+.  The +create_category+ flag
    # will forcefully make the needed directories.
    def save_entry( id, e, create_category=false )
        load_index
        check_id( id )
        e.created ||= (@index.has_key?( id ) ? @index[id].created : now)
        path = entry_path( id )

        unless create_category and File.exists? @basepath
            FileUtils.makedirs File.dirname( path )
        end
        
        File.open( path, 'w' ) { |f| YAML::dump( e, f ) }

        @entry_cache ||= {}
        e.id = id
        e.link = e.class.url_link e, @link, @weblog.central_ext
        e.updated = e.modified = now
        @entry_cache[id] = e

        @index[id] = @weblog.index_class.new( e ) do |i|
            i.updated = e.updated
        end
        @updated[id] = e.updated
        # catalog_search_entry( e )
        sort_index( true )
        e
    end

    # Loads the entry object identified by +id+.  Entries are cached for future loading.
    def load_entry( id )
        return default_entry( @default_author ) if id == default_entry_id
        load_index
        check_id( id )
        @entry_cache ||= {}
        unless @entry_cache.has_key? id
            entry_file = entry_path( id )
            e = Hobix::Entry::load( entry_file )
            e.id = id
            e.link = e.class.url_link e, @link, @weblog.central_ext
            e.updated = updated( id )
            unless e.created
                e.created = @index[id].created
                e.modified = @index[id].modified
                File.open( entry_file, 'w' ) { |f| YAML::dump( e, f ) }
            end
            @entry_cache[id] = e
        else
            @entry_cache[id]
        end
    end

    # Loads the search engine database.  The database will be cleansed and re-scanned if +wash+ is true.
    # def load_search_index( wash )
    #     @search_index = Hobix::Search::Simple::Searcher.load( File.join( @basepath, 'index.search' ), wash )
    # end

    # Catalogs an entry object +e+ in the search engine.
    # def catalog_search_entry( e )
    #     @search_index.catalog( Hobix::Search::Simple::Content.new( e.to_search, e.id, e.modified, e.content_ratings ) )
    # end

    # Determines if the search engine has already scanned an entry represented by IndexEntry +ie+.
    # def search_needs_update? ie 
    #     not @search_index.has_entry? ie.id, ie.modified
    # end

    # Load the internal index (saved at @entry_path/index.hobix) and refresh any timestamps
    # which may be stale.
    def load_index
        return false if @index
        index_path = File.join( @basepath, 'index.hobix' )
        index = if File.exists? index_path
                    YAML::load( File.open( index_path ) )
                else
                    YAML::Omap::new
                end
        @index = YAML::Omap::new
        # load_search_index( index.length == 0 )

        modified = false
        index_fields = @weblog.index_class.properties.keys
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
                @updated[entry_id] = File.mtime( path )

                index_entry = nil
                if ( index.has_key? entry_id ) and !( index[entry_id].is_a? ::Time ) # pre-0.4 index format
                    index_entry = index[entry_id]
                end
                ## we will (re)load the entry if:
                if not index_entry.respond_to?( :updated ) or # it's new
                        ( index_entry.updated != @updated[entry_id] ) # it's changed
                        # or index_fields.detect { |f| index_entry.send( f ).nil? } # index fields have been added
                        # or search_needs_update? index_entry # entry is old or not available in search db

                    puts "++ Reloaded #{ entry_id }"
                    efile = entry_path( entry_id )
                    e = Hobix::Entry::load( efile )
                    e.id = entry_id
                    index_entry = @weblog.index_class.new( e, index_fields ) do |i|
                        i.updated = @updated[entry_id]
                    end
                    # catalog_search_entry( e )
                    modified = true
                end
                index_entry.id = entry_id
                @index[entry_id] = index_entry
            end
        end
        sort_index( modified )
        true
    end

    # Sorts the internal entry index (used by load_index.)
    def sort_index( modified )
        return unless @index
        index_path = File.join( @basepath, 'index.hobix' )
        @index.sort! { |x,y| y[1].created <=> x[1].created }
        if modified
            File.open( index_path, 'w' ) do |f|
              YAML::dump( @index, f )
            end
            # @search_index.dump
        end
    end

    # Returns a Hobix::Storage::FileSys object with its scope limited
    # to entries inside a certain path +p+.
    def path_storage( p )
        return self if ['', '.'].include? p
        load_index
        path_storage = self.dup
        path_storage.instance_eval do
            @index = @index.dup.delete_if do |id, entry|
                if id.index( p ) != 0
                    @updated.delete( p )
                    true
                end
            end
        end
        path_storage
    end

    # Returns an Array all `sections', or directories which contain entries.
    # If you have three entries: `news/article1', `about/me', and `news/misc/article2',
    # then you have three sections: `news', `about', `news/misc'.
    def sections( opts = nil )
        load_index
        hsh = {}
        @index.collect { |id, e| e.section_id }.uniq.sort
    end

    # Find entries based on criteria from the +search+ hash.
    # Possible criteria include:
    #
    # :after:: Select entries created after a given Time.
    # :before:: Select entries created before a given Time.
    # :inpath:: Select entries contained within a path.
    # :match:: Select entries with an +id+ which match a Regexp.
    # :search:: Fulltext search of entries for search words.
    # :lastn:: Limit the search to include only a given number of entries.
    #
    # This method returns an Array of +IndexEntry+ objects for use in
    # skel_* methods.
    def find( search = {} )
        load_index
        _index = @index
        if _index.empty?
            e = default_entry( @default_author )
            @updated[e.id] = e.updated
            _index = {e.id => @weblog.index_class.new(e)}
        end
        # if search[:search]
        #     sr = @search_index.find_words( search[:search] )
        # end
        unless search[:all]
            ignore_test = nil
            ignored = @weblog.sections_ignored
            unless ignored.empty?
                ignore_test = /^(#{ ignored.collect { |i| Regexp.quote( i ) }.join( '|' ) })/
            end
        end
        entries = _index.collect do |id, entry|
                      skip = false
                      if ignore_test and not search[:all]
                          skip = entry.id =~ ignore_test
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
                                     not entry.id.match sval
                                 # when :search
                                 #     not sr.results[entry.id]
                                 else
                                     false
                                 end
                      end
                      if skip then nil else entry end
                  end.compact
        entries.slice!( search[:lastn]..-1 ) if search[:lastn] and entries.length > search[:lastn]
        entries
    end

    # Returns a Time object for the latest updated time for a group of
    # +entries+ (pass in an Array of IndexEntry objects).
    def last_updated( entries )
        entries.collect do |entry|
            updated( entry.id )
        end.max
    end

    # Returns a Time object for the latest modified time for a group of
    # +entries+ (pass in an Array of IndexEntry objects).
    def last_modified( entries )
        entries.collect do |entry|
            entry.modified
        end.max
    end

    # Returns a Time object for the latest creation time for a group of
    # +entries+ (pass in an Array of IndexEntry objects).
    def last_created( entries )
        entries.collect do |entry|
            entry.created
        end.max
    end

    # Returns a Time object representing the +updated+ time for the
    # entry identified by +entry_id+.  Takes into account attachments
    # which have been updated.
    def updated( entry_id )
        find_attached( entry_id ).inject( @updated[entry_id] ) do |max, ext|
            mtime = File.mtime( entry_path( entry_id, ext ) )
            mtime > max ? mtime : max
        end
    end

    # Returns an Array of Arrays representing the months which contain
    # +entries+ (pass in an Array of IndexEntry objects).
    #
    # See Hobix::Weblog.skel_month for an example of this method's usage.
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
            months << [ start, month_end, start.strftime( "/%Y/%m/" ) ] unless find( :after => start, :before => month_end).empty?
            start = month_end + 1
        end
        months
    end

    # Discovers attachments to an entry identified by +id+.
    def find_attached( id )
        check_id( id )
        Dir[ entry_path( id, '*' ) ].collect do |att|
            atp = att.match( /#{ Regexp::quote( id ) }\.(?!#{ extension }$)/ )
            atp.post_match if atp
        end.compact
    end

    # Loads an attachment to an entry identified by +id+.  Entries
    # can have any kind of YAML attachment, each which a specific extension.
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

    # Saves an attachment to an entry identified by +id+.  The attachment
    # +e+ is saved with an extension +ext+.
    def save_attached( id, ext, e )
        check_id( id )
        File.open( entry_path( id, ext ), 'w' ) do |f|
          YAML::dump( e, f )
        end

        @attach_cache ||= {}
        @attach_cache[id] = e
    end

    # Appends the given items to an entry attachment with the given type, and
    # then saves the modified attachment. If an attachment of the given type
    # does not exist, it will be created.
    def append_to_attachment( entry_id, attachment_type, *items )
        attachment = load_attached( entry_id, attachment_type ) rescue []
        attachment += items
        save_attached( entry_id, attachment_type, attachment )
    end
end
end
end
