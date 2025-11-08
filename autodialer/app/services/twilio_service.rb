require "twilio-ruby"
class TwilioService
def initialize
@client = Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"])
@from = ENV["TWILIO_PHONE_NUMBER"]
end
def make_call(to, message = "Hello from Autodialer")
call = @client.calls.create(
from: @from,
to: to,
twiml: "<Response><Say voice='Polly.Aditi' language='en-IN'>#{message}</Say></Response>"
)
{ success: true, sid: call.sid, status: call.status }
rescue Twilio::REST::RestError => e
{ success: false, error: e.message }
end
end