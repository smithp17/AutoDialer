require "net/http"
require "json"
require "uri"

class PerplexityClient
  def initialize(api_key: ENV["PPLX_API_KEY"], model: ENV["PPLX_MODEL"] || "sonar-pro")
    @api_key = api_key
    @model   = model # valid: "sonar", "sonar-pro", "sonar-reasoning", etc.
    @base    = "https://api.perplexity.ai"
  end

  def chat(messages, max_tokens: 300, temperature: 0.2)
    uri = URI("#{@base}/chat/completions")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Content-Type"]  = "application/json"
    req.body = JSON.dump({
      model: @model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens, # short responses [web:261]
      response_format: { type: "text" }
    })
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.request(req)
    raise "Perplexity API error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body)
    data.dig("choices", 0, "message", "content").to_s
  end
end
