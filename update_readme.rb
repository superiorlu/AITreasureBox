# 代码部分来自ChatGPT
require 'net/http'
require 'uri'
require 'json'

# 更新 README 指定范围内容
def update_readme(start_str, end_str, file_name)
  readme = File.read(file_name)
  lines = readme.lines
  start_index = lines.index {|e| e.include?(start_str)}
  end_index = lines.index {|e| e.include?(end_str)}
  repos = []
  Array(lines[start_index...end_index]).each_with_index do |line, index|
    if index > 2
        _, _, repo_info, desc  = line.split('|')
        next if repo_info.nil?
        match = repo_info.match(/\[(.*?)\]/)
        next if match.nil?
        star_count = get_star_count(match[1])
        repo = { repo_info: repo_info, desc: desc, star_count:  star_count }
        repos << repo
    end
  end

  new_readme = ''
  new_readme << lines[0..(start_index + 2)].join
  repos.sort_by!{ |r| -r[:star_count] }
  repos.each_with_index do |repo, index|
    line = format("| %i|%s|%s|\n", index + 1, repo[:repo_info], repo[:desc])
    new_readme << line
  end
  new_readme << lines[end_index..-1].join
  File.write(file_name, new_readme)
end

# 获取指定仓库的 star 数
def get_star_count(repo)
  uri = URI("https://api.github.com/repos/#{repo}")
  headers = {
    'User-Agent': 'Mozilla/5.0',
    'Accept': 'application/vnd.github.v3+json'
  }
  Net::HTTP.start(uri.host, uri.port,
    :use_ssl => uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri
      response = http.request request
    if response.code == '200'
      result = JSON.parse(response.body)
      result['stargazers_count']
    else
      0
    end
  end
end


# 主程序入口
if __FILE__ == $0
  update_readme('## 代码库', '## 工具', 'README.md')
  update_readme('## Repos', '## Tools', 'README.en.md')
end