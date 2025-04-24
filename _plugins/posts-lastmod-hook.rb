#!/usr/bin/env ruby
#
# Check for changed posts

Jekyll::Hooks.register :posts, :post_init do |post|

  # Controlla se il file è tracciato da Git
  tracked = system("git ls-files --error-unmatch \"#{post.path}\" > /dev/null 2>&1")

  if tracked
    commit_num = `git rev-list --count HEAD "#{post.path}"`.to_i

    if commit_num > 1
      lastmod_date = `git log -1 --pretty="%ad" --date=iso "#{post.path}"`.strip
      post.data['last_modified_at'] = lastmod_date
    end
  end

end
