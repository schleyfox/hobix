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
class BasePlugin
    @@plugins = {}
    @@required_from = nil
    def BasePlugin.start( req, weblog )
        @@required_from = req
        if req.tainted?
            req.untaint if req =~ /^[\w\/\\]+$/
        end
        require( req )
        @@required_from = nil

        if @@plugins[req]
            @@plugins[req].collect do |p|
                p.new( weblog )
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

class BaseStorage < BasePlugin
    def all
        find
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

class BaseOutput < BasePlugin
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
end
