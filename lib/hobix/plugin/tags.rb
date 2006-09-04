## tags.rb -- Hobix tag list plugin
##
## Displays a list of all the tags of your blog.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), simply
##    add 'hobix/plugin/tags' to the 'required' list, as follows:
##
## required:
##   - hobix/plugin/tags
##
##    And that's it!
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_tag_list' item.

class Hobix::Out::Quick
  def tags_list(entries)
    tags = { }
    entries.each do |e|
      if e.tags
        e.tags.each do |t|
          tags[t] ||= 0
          tags[t] += 1
        end
      end
    end
    tags
  end

  def sidebar_tag_list_erb
    %q{
        <div class="sidebarBox">
        <h2 class="sidebarTitle">Tags</h2>
        <ul>
        <% tags_list(weblog.storage.find).sort.each do |name, count| %>
          <li>
            <a href="<%= weblog.expand_path "tags/#{ name }/" %>"><%= name
            %></a>:&nbsp;<%=count%>
          </li>
        <% end %>
        </ul>
        </div>
      }
  end

  alias tags_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = tags_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_tag_list', 'sidebar_hobix']
    else
      l + ['sidebar_tag_list']
    end
  end

end
