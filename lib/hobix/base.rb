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
    def default_entry_id; "hobix-default-entry"; end
    def default_entry( author )
        Hobix::Entry.new do |e|
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

module ToYamlExtras
    def to_yaml_properties
        property_map.find_all do |prop, req, edit|
            case req
            when :opt
                val = nil
                if respond_to?( "default_#{ prop[1..-1] }" )
                    val = method( "default_#{ prop[1..-1] }" ).call
                end
                val != instance_variable_get( prop )
            when :req
                true
            end
        end.
        collect do |prop, req|
            prop
        end
    end
end
end
