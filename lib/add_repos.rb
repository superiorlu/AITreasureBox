# partial code from ChatGPT
require 'net/http'
require 'uri'
require 'json'


# add repos
def add_repos
  latest_repos = fetch_repos
  update_repos('## Repos', '**Tip:**', 'README.md', latest_repos)

  latest_repos.each{|repo, repo_info| repo_info[:desc] = repo_info[:cn_desc]}
  update_repos('## 代码库', '**说明:**', 'README.zh-CN.md', latest_repos)
end

# update last date
def update_all_last_update
  last_update_time('# AI TreasureBox', '## Catalog', 'README.md')
  last_update_time('# AI 百宝箱', '## 目录', 'README.zh-CN.md')
end

# update repos content
def update_repos(start_str, end_str, file_name, lasted_repos)
  readme = File.read(file_name)
  lines = readme.lines
  start_index = lines.index {|e| e.include?(start_str)}
  end_index = lines.index {|e| e.include?(end_str)}
  repos = {}
  Array(lines[start_index...end_index]).each_with_index do |line, index|
    if index > 4 # skip head of table
        _, _, repo_info, badge, desc  = line.split('|')
        next if repo_info.nil?
        repo_info.gsub!('🔥', '') # reset fire
        repo_info.gsub!('⭐', '') # reset star
        repo_match = repo_info.scan(/\[(.*?)\]/).flatten
        next if repo_match.empty?

        badge_match = badge.scan(/\[(.*?)\]/).flatten
        date, total_stars, change_stars = badge_match[0].split('_')
        repos[repo_match[0]] = { repo_name: repo_match[0], badge: badge, repo_info: repo_info, desc: desc, star_count:  total_stars.to_i, change_stars: change_stars.to_i, original_index: index - 4 }
    end
  end
  repo_names = repos.keys
  lasted_repos.each do |repo_name, repo_info|
    next if repo_names.include?(repo_name)
    repos[repo_name] = repo_info
  end

  new_readme = ''
  new_readme << lines[0..(start_index + 4)].join
  repo_infos = repos.values
  repo_infos.sort_by!{ |r| -r[:star_count] }
  repo_infos.each_with_index do |repo_info, index|
    now_index = index + 1
    line = format("|%s %i|%s%s|%s|%s|\n",
      star_style(repo_info[:new_coming]),
      now_index,
      popularity_style(repo_info[:change_stars], 200),
      repo_info[:repo_info],
      repo_info[:badge],
      repo_info[:desc]
    )
    new_readme << line
  end
  new_readme << "\n"
  new_readme << lines[end_index..-1].join
  File.write(file_name, new_readme)
end

# new coming style
def star_style(is_new_coming)
  (is_new_coming.nil? || is_new_coming == false) ? '' : '⭐'
end

# code popularity
def popularity_style(change_stars, threshold)
  return ""       if change_stars < threshold
  return "🔥"     if change_stars > threshold && change_stars <= threshold * 2
  return "🔥🔥"   if change_stars > threshold * 2 && change_stars <= threshold * 5
  return "🔥🔥🔥" if change_stars > threshold * 5
end


# last update time
def last_update_time(start_str, end_str, file_name)
  time = Time.now.strftime('%H:%M:%S%Z')
  readme = File.read(file_name)
  lines = readme.lines
  start_index = lines.index {|e| e.include?(start_str)}
  end_index = lines.index {|e| e.include?(end_str)}
  new_readme = ''
  new_readme << lines[0...start_index].join

  Array(lines[start_index...end_index]).each_with_index do |line, index|
    if line.include?('last update')
       prev_time = line.match(/update-(.*)-brightgreen/)
       new_readme << (prev_time.nil? ? line : line.sub(prev_time[1], time))
    else
      new_readme << line
    end
  end
  new_readme << lines[end_index..-1].join
  File.write(file_name, new_readme)
end


# fetch repos
def fetch_repos
  uri = URI.parse(ENV['REPOS_URL'])
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Accept'] = 'application/json'

  response = http.request(request)
  repos = {}
  if response.code == '200'
    result = JSON.parse(response.body)
    Array(result['data']).each do |repo|
      repo_info = format("[%s](%s) ![%s_%s_%s](https://img.shields.io/github/stars/%s.svg)",
        repo['fullName'], repo['link'], repo['crawlDate'], repo['stars'], repo['starsToday'], repo['fullName'])
      latest_repo = { repo_name: repo['fullName'], new_coming: true, repo_info: repo_info, desc: repo['desc'], cn_desc: repo['cnDesc'], star_count: repo['stars'].to_i, change_stars: repo['starsToday'].to_i, original_index: -1 }
      repos[repo['fullName']] = latest_repo
    end
  end
  repos
end

# main
if __FILE__ == $0
  add_repos
  update_all_last_update
end
