## calendar.rb -- Hobix calendar plugin
##
## Displays a one-month calendar in the sidebar. The calendar links
## individual days to a daily, monthly or yearly index page. Daily and
## monthly index pages display the corresponding month in the sidebar;
## yearly pages do something arbitrary and likely to be wrong; other
## pages display the current month.
##
## The plugin generates separate sidebar .html file for each month. It
## places these files in htdocs/calendar/.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), in the
##    'required' block, AFTER the "lib/local" line, append as follows:
##
## required:
##   - hobix/plugin/calendar
##
##    The plugin overwrites some of the default definitions in
##    lib/local.rb, so in most cases it will need to be loaded later.
##    You can also specify any of the following arguments:
##
## required:
##   - hobix/plugin/calendar:
##       start-on-monday: true
##       point-to-index: daily
##       day-symbols: ["Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"]
##
##    Options for 'point-to-index' are 'daily', 'monthly' and
##    'yearly'.
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_calendar' item.
## 2) Every sidebar page is regenerated every time you do an
##    upgen. This is slow.
## 3) The sidebar on yearly index pages is December of that year,
##    regardless of whether that month contains any posts. That's a
##    little weird.

require 'date'

class Array
  def uniq_c
    ret = {}
    each { |e| ret[e] = 1 + (ret[e] || 0) }
    ret
  end
end

module Hobix

## we just keep parameters from hobix.yaml here
class SidebarCalendarPlugin < BasePlugin
  def initialize(weblog, params = {})
    @@start_on_monday = lambda { |x| (x.nil? ? false : x) }[params['start-on-monday']]
    @@point_to_index = (params['point-to-index'] || "monthly").to_sym
    @@day_syms = params['day-symbols'] || (@@start_on_monday ? %w(Mo Tu We Th Fr Sa Su) : %w(Su Mo Tu We Th Fr Sa))
  end

  def self.start_on_monday?; @@start_on_monday; end
  def self.point_to_index; @@point_to_index; end
  def self.day_syms; @@day_syms; end

  DIR = "/calendar"
  def self.dir_to(date, ext = true)
    date.strftime("#{DIR}/sidebar-%Y-%m") + (ext ? ".html" : "")
  end
end

class Out::Quick
  alias calendar_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = calendar_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_calendar', 'sidebar_hobix']
    else
      l + ['sidebar_calendar']
    end
  end

  def sidebar_calendar_ssi
    %q{<!--#include virtual="<%= weblog.link.path + SidebarCalendarPlugin.dir_to(page.timestamp || Time.now)%>"-->}
  end

  def sidebar_erb
    sidebar_calendar_ssi
  end
end

class Weblog
  ## generate all the sidebar calendar files
  def skel_sidebar(path_storage)
    months = path_storage.get_months(storage.find)

    months.extend Hobix::Enumerable
    months.each_with_neighbors do |prev, cur, nexxt| 
      month_start, month_end, month_id = cur

      entries = path_storage.within(month_start, month_end)
      page = Page.new SidebarCalendarPlugin.dir_to(month_start, false)
      page.timestamp = month_start
      page.updated = Time.now #path_storage.last_modified(entries)
      page.prev = prev[0].strftime("/%Y/%m/") if prev
      page.next = nexxt[0].strftime("/%Y/%m/") if nexxt

      days = entries.map do |entry|
        day = entry.created
        Date.new(day.year, day.mon, day.day)
      end.uniq_c
      offset = (month_start.wday - (SidebarCalendarPlugin.start_on_monday? ? 1 : 0)) % 7

      yield :page => page, :months => months, :month => month_start, :days => days, :offset => offset, :day_syms => SidebarCalendarPlugin.day_syms, :index => SidebarCalendarPlugin.point_to_index
    end
  end
end

## generate the HTML
class Out::Quick
  def sidebar_calendar_erb
  %{
    <style type="text/css">
    .sidebarCalendar a { text-decoration: none; font-weight: bold; }
    .sidebarCalendarHeader { text-align: center; }
    .sidebarCalendarContentRow { color: #888; text-align: right; }
    </style>

    <div class="sidebarBox">
    <h2 class="sidebarTitle">Calendar</h2>
    <table class="sidebarCalendar">
      <+ sidebar_calendar_caption +>
      <+ sidebar_calendar_header +>
      <+ sidebar_calendar_contents +>
    </table>
    </div>
  }
  end

  def sidebar_calendar_contents_erb
  %q{
    <tr class="sidebarCalendarContentRow">
    <% offset.times do %>
      <td class="sidebarCalendarFiller"> &nbsp; </td>
    <% end %>
    
    <%
      current = offset
      first = Date.new(month.year, month.mon, 1)
      last = (first >> 1) - 1
    %>

    <% (first .. last).each do |d| %>
      <% if (current % 7) == 0 %>
        </tr><tr class="sidebarCalendarContentRow">
      <% end %>
      <% current += 1 %>

      <% if days.keys.include? d %>
        <% 
          title = d.strftime("%A, %B %e: " + (days[d] == 1 ? "one entry" : "#{days[d]} entries"))
          link = case index
                 when :yearly:
                   d.strftime("/%Y/#%Y%m%d")
                 when :monthly:
                   d.strftime("/%Y/%m/#%Y%m%d")
                 else
                   d.strftime("/%Y/%m/%d.html#%Y%m%d")
                 end
        %>
        <td class="sidebarCalendarLinkDay"><a title="<%= title %>" href="<%= weblog.expand_path link %>"><%= d.strftime("%e") %></a></td>
      <% else %>
        <td class="sidebarCalendarEmptyDay"><%= d.strftime("%e") %></td>
      <% end %>
    <% end %>

    <% (7 - offset).times do %>
      <td class="sidebarCalendarFiller"> &nbsp; </td>
    <% end %>

    </tr>
  }
  end

  def sidebar_calendar_header_erb
  %{
    <tr class="sidebarCalendarHeaderRow">
    <% day_syms.each do |d| %>
      <th class="sidebarCalendarHeader"><%= d %></th>
    <% end %>
    </tr>
  }
  end

  def sidebar_calendar_caption_erb
  %q{
    <caption class="sidebarCalendarCaption">
    <% if page.prev %>
      <a href="<%= weblog.expand_path page.prev %>">&larr;</a>
    <% else %>
      &larr;
    <% end %>
    &nbsp;<a href="<%= weblog.expand_path month.strftime("/%Y/%m/")%>"><%= month.strftime("%B %Y") %></a>&nbsp;
    <% if page.next %>
      <a href="<%= weblog.expand_path page.next %>">&rarr;</a>
    <% else %>
      &rarr;
    <% end %>
    </caption>
  }
  end
end

end
