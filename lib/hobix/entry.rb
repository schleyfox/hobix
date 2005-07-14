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
class Entry < BaseEntry

    _ :title,   :req => true, :edit_as => :text, :search => :fulltext
    _ :tagline, :edit_as => :text, :search => :fulltext, :text_processor => true
    _ :summary, :edit_as => :textarea, :search => :fulltext, :text_processor => true
    _ :content, :req => true, :edit_as => :textarea, :search => :fulltext, :text_processor => true

    # Hobix::Entry objects are typed in YAML as !hobix.com,2004/entry
    # objects.  This type is virtually identical to !okay/news/feed objects,
    # which are documented at http://yaml.kwiki.org/?OkayNews.
    yaml_type "tag:okay.yaml.org,2002:news/entry#1.0"
    yaml_type "tag:hobix.com,2004:entry"

end
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
