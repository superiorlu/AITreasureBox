# 代码部分来自ChatGPT
require 'net/http'
require 'uri'
require 'json'

# 更新 README 指定范围内容
def update_readme(start_str, end_str, file_name, repo_stars)
  readme = File.read(file_name)
  lines = readme.lines
  start_index = lines.index {|e| e.include?(start_str)}
  end_index = lines.index {|e| e.include?(end_str)}
  repos = []
  Array(lines[start_index...end_index]).each_with_index do |line, index|
    if index > 2 # 跳过表头
        _, _, repo_info, desc  = line.split('|')
        next if repo_info.nil?
        match = repo_info.match(/\[(.*?)\]/)
        next if match.nil?
        star_count = if repo_stars[match[1]].nil?
                       get_star_count(match[1])
                     else
                       repo_stars[match[1]]
                     end
        repo_stars[match[1]] = star_count
        repo_info = repo_info.match(/\[(.*?)\].*/)
        repo = { repo_info: repo_info[0], desc: desc, star_count:  star_count, original_index: index - 2 }
        repos << repo
    end
  end

  new_readme = ''
  new_readme << lines[0..(start_index + 2)].join
  repos.sort_by!{ |r| -r[:star_count] }
  repos.each_with_index do |repo, index|
    now_index = index + 1
    line = format("| %i|%s %s|%s|\n", now_index, arrow_style(file_name, repo[:original_index], now_index), repo[:repo_info], repo[:desc])
    new_readme << line
  end
  new_readme << lines[end_index..-1].join
  File.write(file_name, new_readme)
end

# 计算arrow样式
def arrow_style(file_name, original_index, now_index)
  return nil if now_index == original_index
  style = ''
  if file_name == 'README.md'
    style = now_index < original_index ? '<span class="red-up-arrow"></span>' : '<span class="green-down-arrow"></span>'
  else
    style = now_index < original_index ? '<span class="green-up-arrow"></span>' : '<span class="red-down-arrow"></span>'
  end
  style
end

# 获取指定仓库的 star 数
def get_star_count(repo)
  uri = URI.parse("https://api.github.com/repos/#{repo}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = "Bearer #{ENV['GITHUB_TOKEN']}"
  request['Accept'] = 'application/vnd.github+json'
  request['User-Agent'] = 'Mozilla/5.0'

  response = http.request(request)
  if response.code == '200'
    result = JSON.parse(response.body)
    result['stargazers_count']
  else
    0
  end
end


# 主程序入口
if __FILE__ == $0
  repo_stars = {} # 缓存star数
  update_readme('## 代码库', '## 工具', 'README.md', repo_stars)
  update_readme('## Repos', '## Tools', 'README.en.md', repo_stars)
end