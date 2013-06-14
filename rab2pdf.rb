require "sinatra"
require "haml"
require "fileutils"
require "tmpdir"
require "rabbit/command/rabbit"

BASE_URL = "http://myokoym.net/rab2pdf"

get "/" do
  @params ||= {}
  @params[:source] = slide_source
  haml :index
end

post "/convert" do
  begin
    @download_url = convert(params[:source], params[:filename])
    @params = params
    haml :index
  rescue => e
    "Error: #{e}"
  end
end

get "/git" do
  begin
    redirect git(params[:url])
  rescue => e
    "Error: #{e}"
  end
end

private
def convert(source, filename)
  raise "writing too much" if source.size > 20000

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

  File.join(BASE_URL, "pdf", today, filename)
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
   clear-blue

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
