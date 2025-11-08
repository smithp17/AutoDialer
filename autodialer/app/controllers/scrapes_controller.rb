# app/controllers/scrapes_controller.rb
require "open3"
require "fileutils"

class ScrapesController < ApplicationController
  def create
  out_dir  = Rails.root.join("tmp", "scrapes")
  FileUtils.mkdir_p(out_dir)
  json_out = out_dir.join("scraped_profiles.json")
  log_out  = out_dir.join("last_scrape.log")

  script = Rails.root.join("script", "linkedin_scraper.py")
  env    = { "EMAIL" => ENV["EMAIL"].to_s, "PASSWORD" => ENV["PASSWORD"].to_s }

  stdout_str, stderr_str, status = Open3.capture3(env, "python", script.to_s)

  # Move JSON if the Python script wrote to project root
  default_json = Rails.root.join("scraped_profiles.json")
  FileUtils.mv(default_json, json_out, force: true) if File.exist?(default_json)

  # Write logs to file instead of flash to avoid cookie bloat
  File.write(log_out, "--- STDOUT ---\n#{stdout_str}\n\n--- STDERR ---\n#{stderr_str}\n--- STATUS ---\n#{status.exitstatus}\n")

  flash[:notice] = status.success? ? "Scrape finished. See logs below." : "Scrape failed. See logs below."
  # Keep only tiny pointers in flash to avoid CookieOverflow
  flash[:scrape_file] = json_out.exist? ? json_out.to_s : nil
  flash[:log_file]    = log_out.to_s

  redirect_to phone_numbers_path
  end


  def download
    path = Rails.root.join("tmp", "scrapes", "scraped_profiles.json")
    return redirect_to(phone_numbers_path, alert: "No file to download.") unless File.exist?(path)
    send_data File.read(path), filename: "scraped_profiles.json", type: "application/json"  # streams file to the browser [web:320][web:335]
  end
end
