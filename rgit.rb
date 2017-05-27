require "digest/sha1"
require "fileutils"
class BranchError < StandardError
 attr_reader :branch
  def initialize(branch)
    @branch = branch
    super()
  end
end
class Repo
  def initialize(folder)  
    if !File.exists? folder
      Dir.mkdir(folder)
      Dir.mkdir("#{folder}/objects")
      Dir.mkdir("#{folder}/refs")
      Dir.mkdir("#{folder}/refs/heads")
      Dir.mkdir("#{folder}/refs/tags")
      f=File.open("#{folder}/HEAD","w")
      f.puts "heads/master"
      f.close
    end
    @dir=folder
  end
  def new_obj(type,contents)
    hash=sha1(contents)
    if !File.exists? "#{@dir}/objects/#{hash}"
      f=File.open("#{@dir}/objects/#{hash}","w")
      f.puts "#{type}\n"+contents
      f.close
    end
    return hash
  end
  def new_blob(contents)
    return new_obj("blob",contents)
  end
  def new_tree(tree)
    string=""
    tree.each do |name,hash|
      string+="#{hash} #{name}\n"
    end
    return new_obj("tree",string)
  end
  def new_commit(tree,message,parent=nil)
    if parent
      hash=new_obj("commit","tree:#{tree}\nparent:#{parent}\nmessage:#{message}")
    else
      hash=new_obj("commit","tree:#{tree}\nmessage:#{message}")
    end
    return hash
  end
  def commit_parent(hash)
    commit=rd_obj(hash).split("\n")
    chash={}
    commit.each do |line|
      sline=line.split(":")
      chash[sline[0]]=sline[1]
    end
    commit=chash
    return commit["parent"]
  end
  def commit_message(hash)
    commit=rd_obj(hash).split("\n")
    chash={}
    commit.each do |line|
      sline=line.split(":")
      chash[sline[0]]=sline[1]
    end
    commit=chash
    return commit["message"]
  end
  def obj_type(hash)
    f=File.open("#{@dir}/objects/#{hash}","r")
    type=f.gets.chomp!
    f.close
    return type
  end
  def ls_objs()
    objs={}
    listing=Dir.entries("#{@dir}/objects")
    listing.each do |hash|
      unless hash == "." or hash == ".." or hash == ".DS_Store"
        objs[hash]=obj_type(hash)
      end
    end
    return objs
  end
  def rd_obj(hash)
    f=File.open("#{@dir}/objects/#{hash}","r")
    contents=f.readlines
    contents=contents[1..contents.length-1].join("")
    f.close
    return contents
  end
  def update_ref(name,commit)
    f=File.open("#{@dir}/refs/#{name}","w")
    f.puts commit
    f.close
  end
  def read_ref(name)
    f=File.open("#{@dir}/refs/#{name}","r")
    commit=f.gets.chomp!
    f.close 
    return commit 
  end
  def ghead()
    f=File.open("#{@dir}/HEAD","r")
    mhead=f.gets.chomp!
    return mhead
  end
  def shead(nhead)
    f=File.open("#{@dir}/HEAD","w")
    f.puts nhead
    f.close
  end
  def commit(wdir,message)
    wdir.each do |name,contents|
      blob=new_blob(contents)
      wdir[name]=blob
    end
    tree=new_tree(wdir)
    if !File.exists? "#{@dir}/refs/#{ghead}"
      commit=new_commit(tree,message)
    else
      commit=new_commit(tree,message,read_ref(ghead))
    end
    update_ref("#{ghead}",commit)
    return commit
  end
  def branch(name)
    update_ref("heads/#{name}",read_ref(ghead))
  end
  def branches()
    listing=Dir.entries("#{@dir}/refs/heads")
    listing.delete(".")
    listing.delete("..")
    listing.delete(".DS_Store")
    return listing
  end
  def checkout(name)
    if File.exists? "#{@dir}/refs/heads/#{name}"
      shead("heads/#{name}")
    else
      raise BranchError,"Branch #{name} does not exist"
    end
  end
  def merge(name)
    commit=read_ref("heads/#{name}")
    while true
      if commit==read_ref("#{ghead}")
        update_ref("#{ghead}",read_ref("heads/#{name}"))
        return
      end
      parent=commit_parent(commit)
      if parent
        commit=parent
      else
        break
      end
    end
  end
  private
  def sha1(text)
    return Digest::SHA1.hexdigest(text)
  end
end
def log(repo)
  commits={}
  i=0
  repo.branches.each do |branch|
  commits[branch]=repo.read_ref("heads/#{branch}")
  i+=1
  end
  while true do
    i=0
    commits.each do |b,c|
      if "heads/#{b}" == repo.ghead and c == repo.read_ref("heads/#{b}")
        print "*"
      end
      print "#{b}->#{repo.commit_message(c)}"
      if i < commits.length-1
        print ","
      else
        puts
      end
      i+=1
    end
    i=0
    $temp=commits
    commits.each do |b,c|
      p=repo.commit_parent(c)
      if p
        $temp[b]=p
      else
        $temp.delete(b)
      end
    end
    commits=$temp
    if commits=={}
      break
    end
  end
end
def ltest()
  if File.exists? "repo"
    FileUtils.rm_r "repo"
  end
  repo=Repo.new("repo")
  icommit=repo.commit({"hello.txt"=>"hello","hi.txt"=>"hi"},"Initial commit")
  puts "Created initial commit:"
  log(repo)
  repo.branch("release")
  puts "Created branch release:"
  log(repo)
  repo.checkout("release")
  puts "Checked out branch release:"
  log(repo)
  rcommit=repo.commit({"hello.txt"=>"hello","hi.txt"=>"hi","version.txt"=>"10"},"Release commit")
  puts "Created release commit:"
  log(repo)
  repo.checkout("master")
  puts "Checked out branch master:"
  log(repo)
  rcommit=repo.commit({"hello.txt"=>"Hello","hi.txt"=>"Hi",},"Hotfix commit")
  puts "Created hotfix commit:"
  log(repo)
  repo.checkout("release")
  puts "Checked out branch release:"
  log(repo)
  rcommit=repo.commit({"hello.txt"=>"hello","hi.txt"=>"hi","version.txt"=>"1.0"},"Release commit fix")
  puts "Created release commit fix commit:"
  log(repo)
end
#ltest()
if File.exists? "repo"
  FileUtils.rm_r "repo"
end
repo=Repo.new("repo")
icommit=repo.commit({"hello.txt"=>"hello","hi.txt"=>"hi"},"Initial commit")
puts "Created initial commit:"
log(repo) 
repo.branch("release")
puts "Created branch release:"
log(repo)
repo.checkout("release")
puts "Checked out branch release:"
log(repo)
rcommit=repo.commit({"hello.txt"=>"hello","hi.txt"=>"hi","version.txt"=>"1.0"},"Release commit")
puts "Created release commit:"
log(repo)
repo.checkout("master")
puts "Checked out branch master:"
log(repo)
repo.merge("release")
puts "Merged branch release:"
log(repo)