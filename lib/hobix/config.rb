#
# = hobix/config.rb
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

require 'yaml'

module Hobix
class Config
    attr_accessor :weblogs, :username
    def initialize
        @username = ENV['USER'] unless @username
        self
    end
    def Config.load( conf_file )
        c = YAML::load( File::open( conf_file ) )
        c = YAML::object_maker( Hobix::Config, c ) if c.is_a? Hash
        c.initialize
    end
end
end

YAML::add_domain_type( 'whytheluckystiff.net,2004', 'hobix/config' ) do |type, val|
    YAML::object_maker( Hobix::Config, val )
end
