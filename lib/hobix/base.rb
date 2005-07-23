#
# = hobix/weblog.rb
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
require 'redcloth'
require 'yaml'

module YAML
    class Omap
        def keys; map { |k, v| k }; end
    end
end

module Hobix
# The BasePlugin class is *bingo* the underlying class for
# all Hobix plugins.  The +Class::inherited+ hook is used
# by this class to keep track of all classes that inherit
# from it.
class BasePlugin
    @@plugins = {}
    @@required_from = nil
    # Initializes all the plugins, returning
    # an Array of plugin objects.  (Used by the
    # +Hobix::Weblog+ class.)
    def BasePlugin.start( req, weblog )
        opts = nil
        unless req.respond_to? :to_str
            req, opts = req.to_a.first
        end
        @@required_from = req = req.dup
        if req.tainted?
            req.untaint if req =~ /^[\w\/\\]+$/
        end
        require( req )
        @@required_from = nil

        if @@plugins[req]
            @@plugins[req].collect do |p|
                if opts
                    p.new( weblog, opts )
                else
                    p.new( weblog )
                end
            end
        else
            []
        end
    end
    def BasePlugin.inherited( sub )
        @@plugins[@@required_from] ||= []
        @@plugins[@@required_from] << sub
    end
end

# The BaseStorage class outlines the fundamental API for
# all storage plugins.  Storage plugins are responsible
# for abstracting away entry queries and managing the loading
# of Entry objects.  The goal being: cache as much as you can,
# be efficient and tidy.
#
# == Query Methods
#
# find::    Each of the query methods below uses the +find+ method
#           to perform its search.  This method accepts a Hash of
#           parameters.  Please note that calling +find+ without
#           parameters will return all entries which qualify for
#           placement on the front page.
#
# all::     Returns all entries.  Searches find( :all => true )
# lastn::   Returns the last _n_ entries which qualify for the
#           front page.
# inpath::  Returns entries within a path which qualify for the
#           front page.
# after::   Returns entries created after a given date.
# before::  Returns entries created before a given date.
# within::  Returns entries created between a start and
#           end date.
# 
class BaseStorage < BasePlugin
    def initialize( weblog )
        @link = weblog.link
    end
    def default_entry_id; "hobix-default-entry"; end
    def default_entry( author )
        Hobix::Entry.new do |e|
            e.id = default_entry_id 
            e.link = e.class.url_link e, @link, "html"
            e.created = Time.now
            e.modified = Time.now
            e.title = "This Ghostly Message From the Slime Will Soon Vanish!"
            e.tagline = "A temporary message, a tingling sensation, Hobix is up!!"
            e.author = author
            e.content = Hobix::Entry.text_processor.new( "Welcome to Hobix!  Once you make your first blog post, this entry will disappear.  However, in the meantime, you can tweak the CSS of your blog until it suits your satisfaction and you have this bit of words to act as a place holder." )
        end
    end
    def all
        find( :all => true )
    end
    def lastn( n )
        find( :lastn => ( n || 10 ) )
    end
    def inpath( path, n = nil )
        find( :inpath => path, :lastn => n )
    end
    def after( after, n = nil )
        find( :after => after, :lastn => n )
    end
    def before( before, n = nil )
        find( :before => before, :lastn => n )
    end
    def match( expr )
        find( :match => expr )
    end
    def within( after, before )
        find( :after => after, :before => before )
    end
end

# The BaseOutput plugin is the underlying class for all output
# plugins.  These plugins are associated to templates.  Based on
# a template's suffix, the proper output plugin is loaded and
# used to generate page output.
class BaseOutput < BasePlugin
end

# The BasePublish plugin is the underlying class for all publishing
# plugins, which are notified of updates to pages.
#
# Publish plugins are executed after generation of the site.  The plugin
# may choose to watch updates to certain types of pages.  The plugin also
# receives a list of all the pages which have been updated.
#
# Generally, publish plugins fall into two categories:
#
# * Plugins which contact a service when certain updates happen.
#   (Hobix includes an XML-RPC ping, which is triggered whenever
#   the front page is updated.)
# * Plugins which transform Hobix output.  (Hobix includes a
#   replication plugin, which copies updated pages to a remote
#   system via FTP or SFTP.)
#
# == Publish methods
#
# initialize( weblog, settings ):: Like all other plugins, the initialize method takes two parameters,
#                                  a Hobix::Weblog object for the weblog being published and the 
#                                  settings data from the plugin's entry in hobix.yaml.
# watch:: (Optional) Returns an array of page types which, when published, activate the plugin.
# publish( pages ):: If pages are published and the watch criteria qualifies this plugin,
#                    this method is called with a hash of pages published.  The key is the page type
#                    and the value is an array of Page objects.
class BasePublish < BasePlugin
end

# The BaseFacet plugin is the superclass for all plugins which have
# an interface (CGI, UI, etc.)  These interfaces expose some functionality
# to the user through an entry form or series of views.
class BaseFacet < BasePlugin
    def self.not_found app
        app.send_not_found "Action `#{ app.action_uri }' not found.  If this address should work, check your plugins."
    end
end

# Enumerable::each_with_neighbors from Joel Vanderwerf's 
# enum extenstions.
module Enumerable
    def each_with_neighbors n = 1, empty = nil
        nbrs = [empty] * (2 * n + 1)
        offset = n

        each { |x|
            nbrs.shift
            nbrs.push x
            if offset == 0  # offset is now the offset of the first element, x0,
                yield nbrs    #   of the sequence from the center of nbrs, or 0,
            else            #   if x0 has already passed the center.
                offset -= 1
            end
        }

        n.times {
            nbrs.shift
            nbrs.push empty
            if offset == 0
                yield nbrs
            else
                offset -= 1
            end
        }

        self
    end
end

module BaseProperties
    # Returns the complete list of properties for the immediate class.
    # If called on an inheriting class, inherited properties are included.
    module ClassMethods
        def properties
            if superclass.respond_to? :properties
                s = superclass.properties.dup
                (@__props || {}).each { |k, v| s[k] = v }
                s
            else
                (@__props || {})
            end
        end
        def prop_sections
            if superclass.respond_to? :prop_sections
                s = superclass.prop_sections.dup
                (@__sects || {}).each { |k, v| s[k] = v }
                s
            else
                (@__sects || {})
            end
        end
        # Quick property definitions in class definitions.
        def _ name, opts = nil
            @__props ||= YAML::Omap[]
            @__props[name] = opts
            attr_accessor name unless method_defined? "#{ name }="
        end
        # Property sections
        def _! name, opts = {}
            @__sects ||= YAML::Omap[]
            opts[:__sect] = @__props.last[0] rescue nil
            @__sects[name] = opts
        end
    end
    # Build a simple map of properties
    def property_map
        self.class.properties.map do |name, opts|
            if opts
                yreq = opts[:req] ? :req : :opt
                ["@#{ name }", yreq] if yreq
            end
        end.compact
    end
    # Build a property map for the YAML module
    def to_yaml_properties
        property_map.find_all do |prop, req|
            case req
            when :opt
                not instance_variable_get( prop ).nil?
            when :req
                true
            end
        end.
        collect do |prop, req|
            prop
        end
    end
    def self.append_features klass
        super
        klass.extend ClassMethods
    end
end

# placed here to avoid dependency cycle between base.rb and weblog.rb
class Weblog
    @@entry_classes = []
    def self.add_entry_class( c )
        @@entry_classes << c
    end
end

class BaseContent
    include BaseProperties

    _! 'Entry Information'
    _ :id
    _ :link
    _ :title,               :edit_as => :text, :search => :fulltext
    _ :created,             :edit_as => :datetime, :search => :prefix
    _ :modified
    _ :tags,                :edit_as => :text, :search => :prefix

    def initialize; yield self if block_given?; end
    def day_id; created.strftime( "%Y/%m/%d" ) if created; end
    def month_id; created.strftime( "%Y/%m" ) if created; end
    def year_id; created.strftime( "%Y" ) if created; end
    def section_id; File.dirname( id ) if id; end
    def base_id; File.basename( id ) if id; end
    def self.url_link( e, url = nil, ext = nil ); "#{ url }/#{ link_format e }#{ '.' + ext if ext }"; end
    def self.link_format( e ); e.id; end
    def force_tags; []; end

    #
    # If set to true, tags won't be deduced from the entry id
    #
    @@no_implicit_tags = false

    def self.no_implicit_tags
      @@no_implicit_tags = true
    end

    #
    # When using implicit tag, the blog root (i.e) is not considered
    # unless you set the value of +@@root_tag+ to what you need.
    #
    @@root_tag = nil
    def self.root_tag=( tag )
      @@root_tag = tag
    end
    
    #
    # When computing so-called implicit 'implicit-tag', whether
    # or not we should split the path into several tags
    # (default: false)
    #
    @@split_implicit_tags = false
    
    def self.split_implicit_tags
      @@split_implicit_tags = true
    end

    #
    # return an array of tags deduced from the path
    # i.e. a path like ruby/hobix/foo.yml will lead
    # to [ ruby, hobix ] tags
    # Occurence of . (alone) will be either removed or replaced
    # by the value of +root_tag+
    #
    def path_to_tags( path )
      return [] if @@no_implicit_tags
      return [] if path.nil? 
      if @@split_implicit_tags
        tags_array = path.split("/").find_all { |e| e.size > 0 }
        tags_array.pop # Last item is the entry title
      else
        tags_array = [ File.dirname( path )]
      end
      tags_array.map { |e| e == '.' ? @@root_tag : e }.compact
    end

    # 
    # return canonical tags, i.e. tags that are forced and that are deduced
    # from the entry path
    #
    def canonical_tags( path=nil )
      ( force_tags + path_to_tags( path || self.id ) ).uniq
    end

    def tags;( canonical_tags + Array( @tags ) ).uniq; end

    def self.yaml_type( tag )
        if self.respond_to? :tag_as
            tag_as tag
        else
            if tag =~ /^tag:([^:]+):(.+)$/
                define_method( :to_yaml_type ) { "!#$1/#$2" }
                YAML::add_domain_type( $1, $2 ) { |t, v| self.maker( v ) }
            end
        end
    end

    alias to_yaml_orig to_yaml
    def to_yaml( opts = {} )
        opts[:UseFold] = true if opts.respond_to? :[]
        self.class.text_processor_fields.each do |f|
            v = instance_variable_get( '@' + f )
            if v.is_a? self.class.text_processor
                instance_eval %{
                    def @#{ f }.to_yaml( opts = {} )
                        s = self.to_str
                        def s.to_yaml_style; :fold; end
                        s.to_yaml( opts )
                    end
                }
            end
        end
        to_yaml_orig( opts )
    end

    # Load the weblog entry from a file.
    def self.load( file )
        File.open( file ) { |f| YAML::load( f ) }
    end

    # Accessor which returns the text processor used for untyped
    # strings in Entry fields.  (defaults to +RedCloth+.)
    def self.text_processor; RedCloth; end
    # Returns an Array of fields to which the text processor applies.
    def self.text_processor_fields
        self.properties.map do |name, opts|
            name.to_s if opts and opts[:text_processor]
        end.compact
    end
    # Factory method for generating Entry classes from a hash.  Used
    # by the YAML loader.
    def self.maker( val )
        self::text_processor_fields.each do |f|
            if val[f].respond_to? :value
                str = val[f].value
                def str.to_html
                    self
                end
                val[f] = str
            elsif val[f].respond_to? :to_str
                val[f] = self::text_processor.new( val[f].to_str ) 
            end
        end
        YAML::object_maker( self, val )
    end
end

# The BaseEntry class is the underlying class for all Hobix
# entries (i.e. the content for your website/blahhg.)
class BaseEntry < BaseContent

    _ :id
    _ :link
    _ :title,               :edit_as => :text, :search => :fulltext
    _ :author,              :req => true, :edit_as => :text, :search => :prefix
    _ :contributors,        :edit_as => :array, :search => :prefix
    _ :created,             :edit_as => :datetime, :search => :prefix
    _ :modified
    _ :tags,                :edit_as => :text, :search => :prefix
    _ :content,             :edit_as => :textarea, :search => :fulltext, :text_processor => true
    _ :content_ratings,     :edit_as => :array

    def content_ratings; @content_ratings || [:ham]; end

    def self.inherited( sub )
        Weblog::add_entry_class( sub )
    end

    # Build the searchable text
    def to_search
        self.class.properties.map do |name, opts|
            next unless opts
            val = instance_variable_get( "@#{ name }" )
            next unless val
            val = val.strftime "%Y-%m-%dT%H:%M:%S" if val.respond_to? :strftime
            case opts[:search]
            when :prefix
                "#{ name }:" + val.to_s
            when :fulltext
                val.to_s
            end
        end.compact.join "\n"
    end

end
end
