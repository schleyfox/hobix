#
# = hobix/config.rb
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

require 'yaml'

module Hobix
class Config
    attr_accessor :weblogs, :username, :personal, 
                  :post_upgen, :use_editor
    def initialize
        @username = ENV['USER'] unless @username
        self
    end
    def Config.load( conf_file )
        c = YAML::load( File::open( conf_file ) )
        c.keys.each do |k|
            if k =~ /\s/
                k_ = k.gsub( /\s/, '_' )
                c[k_] = c.delete( k )
            end
        end
        c = YAML::object_maker( Hobix::Config, c )
        c.initialize
    end
end
end
