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
        @@required_from = req
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
    def all
        find( :all => true )
    end
    def lastn( n = 10 )
        find( :lastn => n )
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

# The BasePublish plguin is the underlying class for all publishing
# plugins, which are notified of updates to pages.
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
        to_yaml_property_map.reject do |prop, req|
            req == :opt and not instance_variable_get( prop )
        end.
        collect do |prop, req|
            prop
        end
    end
end
end
