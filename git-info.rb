#!/usr/bin/ruby

#require 'rubygems'
require 'json'
require 'date'

@repo_name = $1 || 'Netflix/Hystrix'
@auth_token = $2 || '9dc66e62bee11d96bd37b79a27f73a9eeb504165'

@api_url = 'https://api.github.com'

def github_api(url, json=true, type='vnd.github.v3+json')
	cmd = "curl -ssss -H \"Accept: application/#{type}\" -H \"Authorization: token #{@auth_token}\""
	if url.start_with?("https://")
		cmd += " #{url}"
	else
		cmd += " #{@api_url}/repos/#{@repo_name}/#{url}"
	end
	if json
		JSON.parse(`#{cmd} 2> /dev/null`)
	else
		`#{cmd} 2> /dev/null`
	end
end

#repo name
resp = github_api("#{@api_url}/repos/#{@repo_name}")

puts "a: ******************************************"
puts "Repository name: #{resp["name"]}"
puts "Repository full name: #{resp["full_name"]}"
puts "******************************************"

#first commit of master
def first_commit
	commit = nil
	resp = github_api("commits")
	sha = resp[-1]["commit"]["sha"]
	while true
		r = github_api("commits?sha=#{sha}&per_page=100")
		if r.count != 1 
			sha = r[-1]["sha"]
			next
		end
		commit = r[0]
		break
	end
	commit
end

puts ""
puts "b: ******************************************"
puts "Date of first commit: #{first_commit["commit"]["committer"]["date"]}"

#last commit of all branches
def last_commit
	resp = github_api("commits")
	resp[0]
end

def last_all_commit
	commit = nil
	resp = github_api("branches")
	resp.each do |b|
		r = github_api("#{b["commit"]["url"]}?per_page=1")
		if commit.nil? or commit["commit"]["committer"]["date"] < r["commit"]["committer"]["date"]
			commit = r
		end
	end
	commit
end

puts "Date of most recent commit: #{last_commit["commit"]["committer"]["date"]}"

#branches
puts ""
puts "c: ******************************************"
puts "Branches:"
puts "******************************************"
resp = github_api("branches")
resp.each do |b|
 puts b["name"]
end

#issues
resp = github_api("issues?state=all")
resp.sort! {|a, b| b["state"] <=> a["state"]}

puts ""
puts "d: ******************************************"
puts "There are #{resp.count} issue(s):"
puts "******************************************"
resp.each do |i|
	puts "#{i["state"]}: #{i["body"]}"
end

def most_issues (issues, state)
  state_issues = issues.select {|i| state.eql?(i["state"]) }
  user_issues = {}
  state_issues.each do |i|
	if user_issues[i["user"]["login"]].nil? 
		user_issues[i["user"]["login"]] = 1
	else
		user_issues[i["user"]["login"]] += 1
	end
  end
  most_user = user_issues.max_by{|k,v| v}
  puts "#{most_user[0]} has the most #{state} issues(#{most_user[1]})"
end

puts ""
puts "e: ******************************************"
most_issues resp, "open"
most_issues resp, "closed"

#open pull request
puts ""
puts "f: ******************************************"
puts "Open pull requests:"
puts "******************************************"
resp = github_api("pulls?state=open")
resp.each do |p|
  puts "Id: #{p["id"]}, title: #{p["title"]}"
end

#contributors
#resp.sort! {|a, b| b["contributions"] <=> a["contributions"]}
puts ""
puts "g: ******************************************"
puts "Top contributors"
puts "******************************************"
resp = github_api("contributors")
resp.each_with_index do |c, i|
	break if i > 4
	puts "#{c["login"]} has contributed #{c["contributions"]}"
end

#last master commit
puts ""
puts "h: ******************************************"
puts "Diff of last commit to master branch:"
puts "******************************************"
resp = github_api("branches/master")
last_master_commit = resp["commit"]
resp = github_api("commits/#{resp["commit"]["sha"]}", false, 'vnd.github.diff')
puts resp

#last none master commit
puts ""
puts "i: ******************************************"
if last_all_commit["sha"] != last_master_commit["sha"]
  resp = github_api("commits/#{last_all_commit["sha"]}", false, 'vnd.github.diff')
  puts "Diff of last commit to none-master branch:"
  puts resp
else
  puts "Last commit was in the master branch. Diff is same as above."
end

#histogram of commits for branch of most commits
def branch_commits
	commits = {}
	resp = github_api("branches")
	resp.each do |b|
		#puts b
		commit_dates = []
		sha = b["commit"]["sha"]
		while true
			r = github_api("commits?sha=#{sha}&per_page=100")
			# puts r
			if r.count != 1 
				sha = r[r.count - 1]["sha"]
				commit_dates = commit_dates.concat(r[0..-1].map {|c| c["commit"]["committer"]["date"]})
				#puts commit_dates
			else
				commit_dates = commit_dates.concat(r.map {|c| c["commit"]["committer"]["date"]})
				break
			end
		end
		commits[b["name"]] = commit_dates
	end
	commits
end

def most_commit_branch (branch_commit_dates)
	name = nil
	commit_count = 0
	branch_commit_dates.each do |k, v|
		if name.nil? or v.count > commit_count
			name = k
			commit_count = v.count
		end
	end
	name
end

branch_commit_dates = branch_commits
most_commit_branch_name = most_commit_branch(branch_commit_dates)

def histogram (dates, type='monthly')
	h = {}
	if type.eql?("monthly")
		(1..12).to_a.each {|m| h[m] = 0 }
		dates.each do |d|
			h[DateTime.strptime(d).month] += 1
		end
	else
		(0..6).to_a.each {|m| h[m] = 0 }
		dates.each do |d|
			h[DateTime.strptime(d).wday] += 1
		end
	end
	h
end

def print_histogram(hist, names)
	hist.keys.sort.each do |k|
		print "#{names[k]} "
		(1..hist[k]).to_a.each {|p| print "+"}
		print "\n"
	end
end

month_names = {1 => "JAN", 2 => "FEB", 3 => "MAR", 4 => "APR", 5 => "MAY", 6 => "JUN", 7 => "JUL", 8 => "AUG", 9=>"SEP",10=>"OCT",11=>"NOV",12=>"DEC"}
week_names = {0=>"SUN", 1=>"MON",2=>"TUE", 3=>"WED", 4=>"THU", 5=>"FRI",6=>"SAT"}

#monthly histogram
puts ""
puts "Bonus ******************************************"
puts "Monthly histogram"
puts "******************************************"
print_histogram(histogram(branch_commit_dates[most_commit_branch_name], "monthly"), month_names)

#weekly histogram
puts ""
puts "Bouns ******************************************"
puts "Weekly histogram"
puts "******************************************"
print_histogram(histogram(branch_commit_dates[most_commit_branch_name], "weekly"), week_names)

