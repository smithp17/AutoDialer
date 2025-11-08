require "json"
require "net/http"
require "uri"

class AiParserService
  SYSTEM_PROMPT = <<~PROMPT
    You are a strict command parser for a phone autodialer.
    Convert the user's instruction into strict JSON with keys:
      - phone: E.164 Indian number like "+91XXXXXXXXXX" (must start with +91 and 10 digits).
      - message: short text (<= 280 chars) to be spoken on the call.
    Rules:
      - Always return JSON only. No prose.
      - If user gives a 10-digit Indian mobile (starting 6-9), normalize to +91XXXXXXXXXX.
      - If no valid Indian phone is found, set phone to null.
      - If no message is provided, set message to "Hello! This is a test call from Autodialer."
  PROMPT

  def initialize
    @api_key  = ENV["PPLX_API_KEY"]
    @base_url = ENV["PPLX_BASE_URL"] || "https://api.perplexity.ai"
    @model    = ENV["PPLX_MODEL"] || "sonar-small-online"
  end

  def parse(user_text)
    return fallback_rule_based(user_text) unless @api_key.to_s.strip.present?
    body = {
      model: @model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user",   content: user_text.to_s }
      ],
      temperature: 0,
      response_format: { type: "json_object" } # ask for JSON output
    }

    uri = URI("#{@base_url}/chat/completions")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Content-Type"]  = "application/json"
    req.body = JSON.dump(body)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    res = http.request(req)

    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      text = data.dig("choices", 0, "message", "content").to_s
      json = JSON.parse(text) rescue {}
      phone   = normalize_indian(json["phone"])
      message = sanitize_message(json["message"])
      return { phone: phone, message: message }
    else
      # fallback if API error
      fallback_rule_based(user_text)
    end
  rescue => _
    fallback_rule_based(user_text)
  end

  private

  def fallback_rule_based(text)
    phone = extract_phone(text)
    msg   = extract_message(text)
    { phone: phone, message: msg }
  end

  def extract_phone(text)
    digits = text.to_s.gsub(/[^\d\+]/, "")
    if (m = digits.match(/(\+91)?0?([6-9]\d{9})/))
      "+91#{m[2]}"
    end
  end

  def extract_message(text)
    if (m = text.match(/\b(?:say|message|tell|speak|announce)\b[:\-]?\s*(.+)$/i))
      return sanitize_message(m[1])
    end
    "Hello! This is a test call from Autodialer."
  end

  def normalize_indian(value)
    s = value.to_s
    return nil if s.empty?
    if (m = s.gsub(/[^\d\+]/, "").match(/(\+91)?0?([6-9]\d{9})/))
      "+91#{m[2]}"
    end
  end

  def sanitize_message(s)
    s = s.to_s.strip
    s[0, 280].presence || "Hello! This is a test call from Autodialer."
  end
end
