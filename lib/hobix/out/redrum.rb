#
# = hobix/out/redrum.rb
#
# Hobix processing of ERB + Textile templates.
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
require 'hobix/out/erb'

module Hobix::Out
class RedRum < ERB
    def extension; "redrum"; end
    alias erb_load load
    def load( file_name, vars )
        RedCloth.new( erb_load( file_name, vars ) ).to_html
    end
end
end
