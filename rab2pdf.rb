require "sinatra"
require "haml"
require "fileutils"
require "tmpdir"
require "uri"
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
    @download_url = convert(source, filename)
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

helpers do
  def source
    if params[:file]
      params[:file][:tempfile].read
    else
      params[:source]
    end
  end

  def filename
    if params[:file]
      param = params[:file][:filename]
      extention = File.extname(param)
      File.basename(param, extention)
    else
      params[:filename]
    end
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

    File.join(base_url, "pdf", today, filename)
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
      download_url = File.join(base_url, "pdf", today, pdf_name)

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

  def base_url
    parts_of_url = {
      :scheme => request.scheme,
      :host   => request.host,
      :port   => request.port,
      :path   => request.script_name,
    }
    URI::Generic.build(parts_of_url).to_s
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
end
