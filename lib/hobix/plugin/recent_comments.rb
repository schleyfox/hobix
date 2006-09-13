## recent_comments.rb -- Hobix recent comments plugin
##
## Displays a list of recent comments posted on your blog.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), simply
##    add 'hobix/plugin/recent_comments' to the 'required' list, as
##    follows:
##
## required:
##   - hobix/plugin/recent_comments
##
##    And that's it!
##
##    You can also specify any of the following arguments:
##
## required:
##   - hobix/plugin/recent_comments:
##       num: <number of comments (default 5)>
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_recent_comments' item.
## 2) Currently pretty slow, as it basically take a brute force
##    approach.

module Hobix

## we just keep parameters from hobix.yaml here
class RecentCommentsPlugin < BasePlugin
  def initialize(weblog, params = {})
    @@num = params["num"] || 5
  end

  def self.num; @@num; end
end

class Hobix::Out::Quick
  def all_comments(weblog, entries)
    entries.map do |ie|
      begin
        comments = weblog.storage.load_attached(ie.id, "comments")
        e = weblog.storage.load_entry ie.id
        comments.each { |c| yield e.link, e.title, c.author, c.created }
      rescue Errno::ENOENT
      end
    end
  end

  def recent_comments(weblog, entries, num)
    comments = []
    all_comments(weblog, entries) { |*c| comments.push c }
    comments.map { |x| x }.sort_by { |x| x[3] }.reverse[0 ... num]
  end

  def sidebar_recent_comments_erb
  %q{
    <div class="sidebarBox">
    <h2 class="sidebarTitle">Recent Comments</h2>
    <ul>
    <% reccomm = recent_comments( weblog, weblog.storage.find, RecentCommentsPlugin.num ) %>
    <% reccomm.each do |link, title, auth, created| %>
      <li><a href="<%= link %>"><%= title %></a> by <%= auth %> on <nobr><%= created.strftime "%d %b at %H:%M" %></nobr></li>
    <% end %>
    <%= "<li>No comments (yet)!</li>" if reccomm.empty? %>
    </ul>
    </div>
  }
  end

  alias recent_comments_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = recent_comments_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_recent_comments', 'sidebar_hobix']
    else
      l + ['sidebar_recent_comments']
    end
  end
end

end
