# partial code from ChatGPT
require 'net/http'
require 'uri'
require 'json'


# update repos
def update_all_repos
  repo_stars = {} # cache stars
  latest_repos = fetch_repos

  update_repos('## Repos', '**Tip:**', 'README.md', repo_stars, latest_repos)
  latest_repos.each{|repo, repo_info| repo_info[:desc] = repo_info[:cn_desc]}
  update_repos('## 代码库', '**说明:**', 'README.zh-CN.md', repo_stars, latest_repos)
end

# update last date
def update_all_last_update
  last_update_time('# AI TreasureBox', '## Catalog', 'README.md')
  last_update_time('# AI 百宝箱', '## 目录', 'README.zh-CN.md')
end

# update repos content
def update_repos(start_str, end_str, file_name, repo_stars, latest_repos)
  readme = File.read(file_name)
  lines = readme.lines
  start_index = lines.index {|e| e.include?(start_str)}
  end_index = lines.index {|e| e.include?(end_str)}
  repos = {}
  Array(lines[start_index...end_index]).each_with_index do |line, index|
    if index > 4 # skip head of table
        _, _, repo_info, desc  = line.split('|')
        next if repo_info.nil?
        repo_info.gsub!('🔥', '') # reset fire
        match = repo_info.scan(/\[(.*?)\]/).flatten
        next if match.empty?
        latest_repo_info = get_repo_info(match[0])
        repo_name = match[0]
        if(!latest_repo_info['full_name'].nil? && latest_repo_info['full_name'] != repo_name)
          repo_name = latest_repo_info['full_name']
        end
        star_count = if repo_stars[repo_name].nil?
                       latest_repo_info['stargazers_count'].to_i
                     else
                       repo_stars[repo_name]
                     end
        repo_stars[repo_name] = star_count
        change_stars = 0
        date, total_stars, change_stars = sync_today_stars(match[1], star_count)
        star_info = format("%s_%s_%s", date, total_stars, change_stars)
        repo_info.sub!(match[1], star_info)
        repos[repo_name] = { repo_name: repo_name, repo_info: repo_info, desc: desc, star_count:  star_count, change_stars: change_stars.to_i, trending: false, original_index: index - 4 }
    end
  end

  # add repos
  repo_names = repos.keys
  latest_repos.each do |repo_name, repo_info|
    if repo_info[:forced] == false
      if repo_names.include?(repo_name)
        repos[repo_name][:trending] = repo_info[:trending]
        next
      end
    end
    repos[repo_name] = repo_info
  end

  new_readme = ''
  new_readme << lines[0..(start_index + 4)].join
  repo_infos = repos.values
  repo_infos.sort_by!{ |r| -r[:star_count] }
  repo_infos.each_with_index do |repo, index|
    now_index = index + 1
    line = format("|%s%s %i|%s%s%s|%s|\n",
      arrow_style(file_name, repo[:original_index], now_index),
      star_style(repo[:trending]),
      now_index,
      popularity_style(repo[:change_stars], 256),
      repo[:repo_info],
      repo[:additional_info],
      repo[:desc]
    )
    new_readme << line
  end
  new_readme << "\n"
  new_readme << lines[end_index..-1].join
  File.write(file_name, new_readme)
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

# trending style
def star_style(trending)
  (trending.nil? || trending == false) ? '' : '⭐'
end

# cumulate arrow style
def arrow_style(file_name, original_index, now_index)
  return nil if original_index == -1
  return nil if now_index == original_index
  style = ' '
  if file_name == 'README.md'
    style = now_index < original_index ? '![green-up-arrow.svg](https://user-images.githubusercontent.com/1154692/228381846-4cd38d29-946d-4268-8bd5-46b4c2531391.svg)' : '![red-down-arrow](https://user-images.githubusercontent.com/1154692/228383555-49b10a2c-d5e6-4963-b286-7351f21c442b.svg)'
  else
    style = now_index < original_index ? '![red-up-arrow](https://user-images.githubusercontent.com/1154692/228383595-95e46fa7-14c3-4b24-a20d-1effa14812cf.svg)' : '![green-down-arrow](https://user-images.githubusercontent.com/1154692/228382543-b474d2ca-6a13-4452-9df0-5941d8cf6a6c.svg)'
  end
  style
end

# code popularity
def popularity_style(change_stars, threshold)
  return ""       if change_stars < threshold
  return "🔥"     if change_stars > threshold && change_stars <= threshold * 2
  return "🔥🔥"   if change_stars > threshold * 2 && change_stars <= threshold * 4
  return "🔥🔥🔥" if change_stars > threshold * 4
end

# cumulate stars changes
def sync_today_stars(info, latest_stars)
  today = Time.now.strftime('%Y-%m-%d')
  if info.nil? || !info.include?('_')
    [today, latest_stars, 0]
  else
    date, total_stars, change_stars = info.split('_')
    if date != today
      change_stars = 0
    end
    if latest_stars.to_i == 0
      [today, total_stars, change_stars]
    else
      change_stars = change_stars.to_i + (latest_stars.to_i - total_stars.to_i)
      [today, latest_stars, change_stars]
    end
  end
end

# fetch repo info from github api
def get_repo_info(repo)
  response = request_with_redirect("https://api.github.com/repos/#{repo}")
  if response&.code == '200'
    JSON.parse(response.body)
  else
    {}
  end
end

# request with redirect when 301 response
def request_with_redirect(url)
  return if url.nil?

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}"
  request['Accept'] = 'application/vnd.github+json'
  request['User-Agent'] = 'Mozilla/5.0'
  response = http.request(request)

  if response.code == '301'
    location_body = JSON.parse(response.body)
    request_with_redirect(location_body['url'])
  elsif response.code == '200'
    response
  end
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
      repo_info = format("[%s](%s) </br> ![%s_%s_%s](https://img.shields.io/github/stars/%s.svg)",
        repo['fullName'], repo['link'], repo['crawlDate'], repo['stars'], repo['starsToday'], repo['fullName'])
      latest_repo = { repo_name: repo['fullName'], trending: true, repo_info: repo_info, desc: repo['desc'], cn_desc: repo['cnDesc'], additional_info: repo['additionalInfo'], star_count: repo['stars'].to_i, change_stars: repo['starsToday'].to_i, forced: repo['forced'], original_index: -1 }
      repos[repo['fullName']] = latest_repo
    end
  end
  repos
end

# main
if __FILE__ == $0
  update_all_repos
  update_all_last_update
end
