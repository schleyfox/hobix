#
# = hobix.rb
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

require 'hobix/config'
require 'hobix/weblog'

module Hobix
    ## Version used to compare installations
    VERSION = '0.1d'
    ## CVS information
    CVS_ID = "$Id$"
    CVS_REV = "$Revision$"[11..-3]
    ## Share directory contains external data files
    SHARE_PATH = "/usr/local/share/hobix/"
end

