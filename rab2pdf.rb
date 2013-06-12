require "sinatra"
require "haml"
require "fileutils"
require "tmpdir"
require "uri"
require "rabbit/command/rabbit"

BASE_URL = "http://myokoym.net/rab2pdf"

get "/" do
  haml :index
end

post "/convert" do
  begin
    @download_url = convert(params)
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
def convert(params)
  source = params[:source]
  raise "writing too much" if source.size > 20000

  filename = params[:filename]
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

  URI.join(BASE_URL, "pdf", today, filename).to_s
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
    download_url = URI.join(BASE_URL, "pdf", today, pdf_name).to_s

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
