class BlogController < ApplicationController
  BLOG_DIR = Rails.root.join("app", "blog")

  def index
    files = Dir.exist?(BLOG_DIR) ? Dir.glob(BLOG_DIR.join("*.md")).sort.reverse : []
    @posts = files.map { |p| fm_for(p) }.compact
  end

  def show
    @post = read_post(params[:slug])
    redirect_to(blog_path, alert: "Post not found") unless @post
  end

  def generate
    topics = params[:titles].to_s.split(/\r?\n/).map(&:strip).reject(&:blank?).first(10)
    return redirect_to(blog_path, alert: "Please provide up to 10 topics (one per line).") if topics.empty?

    client = PerplexityClient.new
    system_prompt = <<~SYS
      You write concise technical micro posts in Markdown.
      Output strictly one micro post per topic, about 30 words (±5), one paragraph each.
      No headings, no numbering, no preface or trailing notes—only the paragraphs.
    SYS
    user_prompt = <<~USER
      Topics:
      #{topics.map.with_index { |t, i| "#{i+1}. #{t}" }.join("\n")}

      Return exactly #{topics.length} paragraphs, one per topic, in the same order, about 30 words each.
    USER

    content = client.chat(
      [
        { role: "system", content: system_prompt },
        { role: "user",   content: user_prompt }
      ],
      max_tokens: 1200,
      temperature: 0.3
    )

    count = write_micro_posts(topics, content)
    if count > 0
      redirect_to blog_path, notice: "Generated #{count} micro post(s)."
    else
      redirect_to blog_path, alert: "No posts generated. Please try again."
    end
  rescue => e
    redirect_to blog_path, alert: "Error: #{e.message}"
  end

  # Keep a single destroy method, above private.
  def destroy
    slug = params[:slug].to_s
    path = Dir.glob(BLOG_DIR.join("*-#{slug}.md")).first
    if path && File.exist?(path)
      File.delete(path)
      redirect_to blog_path, notice: "Deleted “#{slug}”."
    else
      redirect_to blog_path, alert: "Post not found."
    end
  end

  private

  def write_micro_posts(topics, raw)
    require "fileutils"
    FileUtils.mkdir_p(BLOG_DIR)

    # Split output into paragraphs; try line-based first, then double-newline fallback
    lines = raw.to_s.strip.split(/\n+/).map(&:strip).reject(&:blank?)
    lines = raw.to_s.strip.split(/\n{2,}/).map(&:strip).reject(&:blank?) if lines.length < topics.length

    while lines.length < topics.length
      lines << ""
    end
    lines = lines.first(topics.length)

    created = 0
    topics.each_with_index do |topic, idx|
      body = lines[idx].to_s.strip.gsub(/\s+/, " ")
      next if body.blank?

      # Title is exactly the topic; slug from topic
      fm = {
        "title" => topic,
        "date"  => Date.today.to_s,
        "slug"  => parameterize(topic),
        "tags"  => []
      }
      fname = "#{fm["date"]}-#{fm["slug"]}.md"
      File.write(BLOG_DIR.join(fname), normalize_chunk(fm, body))
      created += 1
    rescue => e
      Rails.logger.warn("Blog write error (#{topic}): #{e.message}")
    end

    created
  end

  def normalize_chunk(fm, body)
    <<~MD
    ---
    title: #{fm["title"]}
    date: #{fm["date"]}
    tags: #{fm["tags"].is_a?(Array) ? "[" + fm["tags"].join(", ") + "]" : "[]"}
    slug: #{fm["slug"]}
    ---
    #{body}
    MD
  end

  def read_post(slug)
    path = Dir.glob(BLOG_DIR.join("*-#{slug}.md")).first
    return nil unless path && File.exist?(path)
    fm, body = extract_front_matter_and_body(File.read(path, encoding: "UTF-8"))
    return nil unless fm
    # Title fallback: front matter title -> filename-derived title
    fallback_title = File.basename(path).sub(/^\d{4}-\d{2}-\d{2}-/, "").sub(/\.md$/, "").tr("-", " ").split.map(&:capitalize).join(" ")
    {
      slug:  parameterize(fm["slug"].presence || slug),
      title: (fm["title"].presence || fallback_title),
      date:  fm["date"],
      tags:  (fm["tags"] || []),
      html:  markdown_to_html(body)
    }
  end

  def fm_for(path)
    fm, _ = extract_front_matter_and_body(File.read(path, encoding: "UTF-8"))
    return nil unless fm
    base_slug = fm["slug"].presence || File.basename(path).sub(/^\d{4}-\d{2}-\d{2}-/, "").sub(/\.md$/, "")
    fallback_title = File.basename(path).sub(/^\d{4}-\d{2}-\d{2}-/, "").sub(/\.md$/, "").tr("-", " ").split.map(&:capitalize).join(" ")
    {
      slug:  parameterize(base_slug),
      title: (fm["title"].presence || fallback_title),
      date:  fm["date"],
      tags:  (fm["tags"] || [])
    }
  rescue
    nil
  end

  def extract_front_matter_and_body(md)
    if md =~ /\A---\s*\n(.+?)\n---\s*\n/m
      fm_text = Regexp.last_match(1)
      body    = md.sub(/\A---\s*\n(.+?)\n---\s*\n/m, "")
      fm = YAML.safe_load(fm_text, permitted_classes: [], aliases: false) rescue {}
      [fm, body]
    else
      [nil, nil]
    end
  end

  def markdown_to_html(md)
    require "redcarpet"
    renderer = Redcarpet::Render::HTML.new(with_toc_data: false, hard_wrap: true)
    md_opts  = { fenced_code_blocks: false, tables: false, autolink: true }
    Redcarpet::Markdown.new(renderer, md_opts).render(md.to_s)
  end

  def parameterize(s)
    s.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
  end
end
