#
# = hobix/entry.rb
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

module Hobix
# The Entry class stores complete data for an entry on the site.  All
# entry extensions should behave like this class as well.
#
# == Properties
#
# At the very least, entry data should support the following
# accessors.
#
# id::               The id (or shortName) for this entry.  Includes
#                    the basic entry path.
# link::             The full URL to this entry from the weblog.
# title::            The heading for this entry.
# tagline::          The subheading for this entry.
# tags::             A list of free-tagged categories.
# author::           The author's username.
# contributors::     An Array of contributors' usernames.
# modified::         A modification time.
# created::          The time the Entry was initially created.
# summary::          A brief description of this entry.  Can be used
#                    for an abbreviated text of a long article.
# content::          The full text of the entry.
#
# The following read-only properties are also available:
#
# day_id::           The day ID can act as a path where other
#                    entry, posted on the same day, are stored.
# month_id::         A path for the month's entries.
# year_id::          A path for the year's entries.
class Entry
    attr_accessor :id, :link, :title, :tagline, :summary, :author,
                  :contributors, :modified, :created, :tags,
                  :content
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


    def initialize; yield self if block_given?; end
    def day_id; created.strftime( "%Y/%m/%d" ) if created; end
    def month_id; created.strftime( "%Y/%m" ) if created; end
    def year_id; created.strftime( "%Y" ) if created; end
    def section_id; File.dirname( id ) if id; end
    def force_tags; []; end

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

    def tags; ( canonical_tags + Array( @tags ) ).uniq; end

    include ToYamlExtras
    def property_map
        [
            ['@title', :req, :text], 
            ['@author', :req, :text], 
            ['@contributors', :opt, :textarea], 
            ['@created', :opt, :text], 
            ['@tagline', :opt, :text], 
            ['@tags', :opt, :text],
            ['@summary', :opt, :textarea], 
            ['@content', :req, :textarea]
        ]
    end

    # Hobix::Entry objects are typed in YAML as !hobix.com,2004/entry
    # objects.  This type is virtually identical to !okay/news/feed objects,
    # which are documented at http://yaml.kwiki.org/?OkayNews.
    def to_yaml_type
        "!hobix.com,2004/entry"
    end

    alias to_yaml_orig to_yaml
    def to_yaml( opts = {} )
        opts[:UseFold] = true if opts.respond_to? :[]
        Entry::text_processor_fields.each do |f|
            v = instance_variable_get( '@' + f )
            if v.is_a? Entry::text_processor
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
    def Entry::load( file )
        File.open( file ) { |f| YAML::load( f ) }
    end

    # Accessor which returns the text processor used for untyped
    # strings in Entry fields.  (defaults to +RedCloth+.)
    def Entry::text_processor; RedCloth; end
    # Returns an Array of fields to which the text processor applies.
    def Entry::text_processor_fields; ['content', 'tagline', 'summary']; end
    # Factory method for generating Entry classes from a hash.  Used
    # by the YAML loader.
    def Entry::maker( val )
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
end

YAML::add_domain_type( 'okay.yaml.org,2002', 'news/entry#1.0' ) do |type, val|
    Hobix::Entry::maker( val )
end
YAML::add_domain_type( 'hobix.com,2004', 'entry' ) do |type, val|
    Hobix::Entry::maker( val )
end

module Hobix
# The EntryEnum class is mixed into an Array of entries just before
# passing on to a template.  This Enumerator-like module provides some
# common iteration of entries.
module EntryEnum
    # Calls the block with two arguments: (1) a Time object with
    # the earliest date of an issued post for that day; (2) an
    # Array of entries posted that day, in chronological order.
    def each_day
        last_day, day = nil, []
        each do |e|
            if last_day and last_day != e.day_id
                yield day.first.created, day
                day = []
            end
            last_day = e.day_id
            day << e
        end
        yield day.first.created, day if last_day
    end
end
end
