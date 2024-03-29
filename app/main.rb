require "zlib"
require "digest"

def write_object(file, type)
  content = "#{type} #{file.bytesize}\0#{file}"
  blob_sha = Digest::SHA1.hexdigest(content)
  compressed_contents = Zlib::Deflate.deflate(content)
  Dir.mkdir(".git/objects/#{blob_sha[0..1]}") unless File.directory?(".git/objects/#{blob_sha[0..1]}")
  File.write(".git/objects/#{blob_sha[0..1]}/#{blob_sha[2..]}", "#{compressed_contents}")
  blob_sha
end

def write_tree(dir)
  tree_map = {}
  entries = Dir.entries(dir) - [".", "..", ".git"]

  entries.each do |entry|
    path = "#{dir}/#{entry}"
    if File.directory?(path)
      bin_sha = [write_tree(path)].pack('H*')
      tree_map[entry] = "40000 #{entry}\0#{bin_sha}"

    elsif File.executable?(path)
      file = File.read(path)
      bin_sha = [write_object(file, "blob")].pack("H*")
      tree_map[entry] = "100755 #{entry}\0#{bin_sha}"
    else
      file = File.read(path)
      bin_sha = [write_object(file, "blob")].pack("H*")
      tree_map[entry] = "100644 #{entry}\0#{bin_sha}"
    end
  end
  tree = ""
  tree_map.sort_by{|key, value| key}.each do |key, value|
    tree += value
  end
  write_object(tree, "tree")
end


command = ARGV[0]
case command

when "init"
  Dir.mkdir(".git")
  Dir.mkdir(".git/objects")
  Dir.mkdir(".git/refs")
  File.write(".git/HEAD", "ref: refs/heads/main\n")
  puts "Initialized git directory"

when "cat-file"
  if ARGV[1] == "-p"
    blob_sha = ARGV[2]
    blob_path = ".git/objects/#{blob_sha[0..1]}/#{blob_sha[2..]}"

    compressed_contents = File.read(blob_path, mode:"rb")
    inflater = Zlib::Inflate.new
    raw_contents = inflater.inflate(compressed_contents)
    inflater.finish

    idx = raw_contents.index("\0") + 1
    print raw_contents[idx..]

  else
    raise "i don't know that one"
  end

when "hash-object"
  if ARGV[1] == "-w"
    file = File.read(ARGV[2])
    print write_object(file, "blob")

  else
    raise "i dont even know that one !"
  end

when "write-tree"
  puts write_tree(".")

when "ls-tree"
  if ARGV[1] == "--name-only"
    tree_sha = ARGV[2]
    tree_path = ".git/objects/#{tree_sha[0..1]}/#{tree_sha[2..]}"
    compressed_contents = File.read(tree_path, mode:"rb")

    inflater = Zlib::Inflate.new
    content = inflater.inflate(compressed_contents)
    inflater.finish

    content = content[(content.index("\0") + 1)..]
    while(true)
      space_idx = content.index(" ")
      null_idx = content.index("\x00")
      break if space_idx.nil? or null_idx.nil?

      puts(content[(space_idx+1)..(null_idx-1)])
      content = content[(null_idx+1)..]
    end

  else
    raise "i dont know!"
  end

when "commit-tree"
  commit = "tree #{ARGV[1]}\n"
  msg = ""
  if ARGV[2] == "-m"
    msg = ARGV[3]
  else
    commit += "parent #{ARGV[3]}"
    msg = ARGV[5]
  end
  commit += "author connor <connoro.toro@gmail.com> #{Time.now.to_i}\n"
  commit += "committer connor <connoro.toro@gmail.com> #{Time.now.to_i}\n\n"
  commit += "#{msg}\n"
  print write_object(commit, "commit")
else
  raise RuntimeError.new("Unknown command #{command}")
end
