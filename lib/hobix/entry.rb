#
# = hobix/entry.rb
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
# author::           The author's abbreviated name.
# contributors::     An Array of contributors' abbreviated names.
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
                  :contributors, :modified, :created,
                  :content

    def day_id; created.strftime( "/%Y/%m/%d/" ); end
    def month_id; created.strftime( "/%Y/%m/" ); end
    def year_id; created.strftime( "/%Y/" ); end
    def section_id; id.gsub( /(^|\/)[^\/]+$/, '' ); end

    include ToYamlExtras
    def to_yaml_property_map
        [
            ['@title', :req], 
            ['@author', :req], 
            ['@contributors', :opt], 
            ['@created', :opt], 
            ['@tagline', :opt], 
            ['@summary', :opt], 
            ['@content', :req]
        ]
    end

    def to_yaml_type
        "!hobix.com,2004/entry"
    end

    alias to_yaml_orig to_yaml
    def to_yaml( opts = {} )
        opts[:UseFold] = true
        Entry::text_processor_fields.each do |f|
            v = instance_variable_get( '@' + f )
            if v.is_a? Entry::text_processor
                instance_eval %{
                    def @#{ f }.to_yaml( opts = {} )
                        self.to_str.to_yaml( opts )
                    end
                }
            end
        end
        to_yaml_orig( opts )
    end

    # Load the weblog entry from a file.
    def Entry::load( file )
        YAML::load( File::open( file ) )
    end

    # Accessor which returns the text processor used for untyped
    # strings in Entry fields.  (defaults to +RedCloth+.)
    def Entry::text_processor; RedCloth; end
    # Returns an Array of fields to which the text processor applies.
    def Entry::text_processor_fields; ['content', 'tagline', 'summary']; end

end
end

entry_proc = Proc.new do |type, val|
    Hobix::Entry::text_processor_fields.each do |f|
        if val[f].respond_to? :value
            str = val[f].value
            def str.to_html
                self
            end
            val[f] = str
        elsif val[f].respond_to? :to_str
            val[f] = Hobix::Entry::text_processor.new( val[f].to_str ) 
        end
    end
    YAML::object_maker( Hobix::Entry, val )
end
YAML::add_domain_type( 'okay.yaml.org,2002', 'news/entry#1.0', &entry_proc )
YAML::add_domain_type( 'hobix.com,2004', 'entry', &entry_proc )

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
