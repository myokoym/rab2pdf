require "sinatra"
require "haml"
require "fileutils"
require "rabbit/command/rabbit"

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

private
def convert(params)
  base_dir = "public/pdf"
  FileUtils.mkdir_p(base_dir)
  pdf_path = File.join(base_dir, params[:filename])

  Tempfile.open(["rab2pdf", ".rab"]) do |tempfile|
    tempfile.puts(params[:source])
    tempfile.flush
    Rabbit::Command::Rabbit.run("--print",
                                "--output-filename", pdf_path,
                                tempfile.path)
  end

  File.join("http://myokoym.net/rab2pdf", "pdf", params[:filename])
end
