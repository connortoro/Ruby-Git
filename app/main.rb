require "zlib"
require "digest"

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
    raise "i dont know that one"
  end

when "hash-object"
  if ARGV[1] == "-w"
    file_contents = File.read(ARGV[2])
    content = "blob #{file_contents.bytesize}\0#{file_contents}"

    blob_sha = Digest::SHA1.hexdigest(content)
    compressed_contents = Zlib::Deflate.deflate(content)

    Dir.mkdir(".git/objects/#{blob_sha[0..1]}")
    File.write(".git/objects/#{blob_sha[0..1]}/#{blob_sha[2..]}", "#{compressed_contents}")
    print(blob_sha)
  else
    raise "i dont know that one!"
  end

else
  raise RuntimeError.new("Unknown command #{command}")
end
