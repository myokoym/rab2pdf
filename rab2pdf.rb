require "sinatra"
require "haml"
require "fileutils"
require "tmpdir"
require "rabbit/command/rabbit"

class SourceSizeError    < StandardError; end
class FilenameEmptyError < StandardError; end

get "/" do
  @params ||= {}
  @params[:source] = slide_source
  haml :index
end

post "/" do
  begin
    if params[:file]
      @download_url = convert(read_file, get_filename)
    else
      @download_url = convert(params[:source], params[:filename])
    end
  rescue SourceSizeError => e
    @source_error_message = e
  rescue FilenameEmptyError => e
    @filename_error_message = e
  rescue => e
    return "Error: #{e}"
  end

  @params = params
  haml :index
end

get "/git" do
  begin
    redirect git(params[:url])
  rescue => e
    "Error: #{e}"
  end
end

private

def get_filename
  param = params[:file][:filename]
  ext = File.extname(param)
  File.basename(param, ext)
end

def read_file
  params[:file][:tempfile].read
end

def convert(source, filename)
  raise FilenameEmptyError, "required!" if filename.empty?
  raise SourceSizeError, "error: writing too much!" if source.size > 20000

  filename << ".pdf" unless /\.(?:ps|pdf|svg)\z/i =~ filename

  today = Time.now.strftime("%Y%m%d")
  base_dir = "public/pdf/#{today}"
  FileUtils.mkdir_p(base_dir)
  pdf_path = File.join(base_dir, filename)

  Tempfile.open(["rab2pdf", ".rab"]) do |tempfile|
    tempfile.puts(source)
    tempfile.flush
    Rabbit::Command::Rabbit.run("--print",
                                "--output-filename", pdf_path,
                                tempfile.path)
  end

  File.join(request.url, "pdf", today, filename)
end

def git(url)
  download_url = nil

  Dir.mktmpdir do |tmpdir|
    FileUtils.cd(tmpdir) do
      system("git", "clone", "--quiet", url)
    end

    repo_name = File.basename(url, ".git")
    repo_path = File.join(tmpdir, repo_name)
    rab_name = File.open(File.join(repo_path, ".rabbit")).read.chomp

    today = Time.now.strftime("%Y%m%d")
    pdf_name = rab_name.gsub(/\.\w+\z/, ".pdf")
    download_url = File.join(BASE_URL, "pdf", today, pdf_name)

    base_dir = File.expand_path("public/pdf/#{today}")
    FileUtils.mkdir_p(base_dir)
    pdf_path = File.join(base_dir, pdf_name)

    FileUtils.cd(repo_path) do
      Rabbit::Command::Rabbit.run("--print",
                                  "--output-filename", pdf_path,
                                  rab_name)
    end
  end

  download_url
end

def slide_source
  <<-EOS
= TITLE

# : subtitle
#    SUBTITLE
: author
   Your Name
# : institution
#    INSTITUTION
# : content-source
#    EVENT NAME
: date
   #{Time.now.strftime("%Y/%m/%d")}
# : allotted-time
#    5m
: theme
   lightning-clear-blue

= FIRST SLIDE

  * ITEM 1
  * ITEM 2
  * ITEM 3

= SECOND SLIDE

  # image
  # src = https://raw.github.com/rabbit-shocker/rabbit/master/sample/lavie.png
  # relative_height = 100
  EOS
end
