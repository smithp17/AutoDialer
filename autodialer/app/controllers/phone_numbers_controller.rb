class PhoneNumbersController < ApplicationController
  # Only load @phone_number for actions that actually exist
  before_action :set_phone_number, only: [:call_now]

  def index
    @phone_numbers = PhoneNumber.order(created_at: :desc)
    @statistics = {
      total: PhoneNumber.count,
      completed: PhoneNumber.where(status: 'completed').count,
      failed:   PhoneNumber.where(status: 'failed').count,
      pending:  PhoneNumber.where(status: 'pending').count
    }
  end

  # Paste up to 100 numbers (one per line or comma-separated)
  def bulk_upload
    if params[:numbers_text].present?
      numbers = params[:numbers_text].split(/[\n,]/).map(&:strip).reject(&:blank?)
      created = 0
      errors  = []

      numbers.first(100).each do |num|
        phone = PhoneNumber.new(number: num, status: 'pending')
        if phone.save
          created += 1
        else
          errors << "#{num}: #{phone.errors.full_messages.join(', ')}"
        end
      end

      flash[:notice] = "Added #{created} phone numbers"
      flash[:alert]  = errors.join("<br>").html_safe if errors.any?
    end
    redirect_to phone_numbers_path
  end

  # Call a single number now
  def call_now
    twilio  = TwilioService.new
    message = params[:message] || "Hello! This is a test call from Autodialer."

    @phone_number.update(status: 'calling')
    result = twilio.make_call(@phone_number.number, message)

    if result[:success]
      @phone_number.update(call_sid: result[:sid], called_at: Time.current)
      CallLog.create(phone_number: @phone_number, status: 'queued', message: message, started_at: Time.current)
      flash[:notice] = "Call initiated"
    else
      @phone_number.update(status: 'failed')
      flash[:alert] = "Call failed: #{result[:error]}"
    end

    redirect_to phone_numbers_path
  end

  # Sequentially call all pending numbers (rate-limited with a small delay)
  def call_all
    pending = PhoneNumber.where(status: 'pending').limit(100)
    if pending.empty?
      flash[:alert] = "No pending numbers"
      return redirect_to phone_numbers_path
    end

    twilio      = TwilioService.new
    message     = params[:message] || "Hello from Autodialer"
    success_cnt = 0
    failed_cnt  = 0

    pending.each do |phone|
      phone.update(status: 'calling')
      result = twilio.make_call(phone.number, message)
      if result[:success]
        phone.update(call_sid: result[:sid], called_at: Time.current)
        success_cnt += 1
      else
        phone.update(status: 'failed')
        failed_cnt += 1
      end
      sleep 2
    end

    flash[:notice] = "Called #{success_cnt}. Failed: #{failed_cnt}"
    redirect_to phone_numbers_path
  end

  # AI prompt: parse free-form text via LLM (Perplexity/OpenAI-compatible) and place a call
  def ai_prompt
  input  = params[:prompt].to_s.strip
  parser = AiParserService.new
  parsed = parser.parse(input)

  number  = parsed[:phone]
  message = parsed[:message]

  # Fallback: if no number in prompt, use the most recently added number
  if number.blank?
    recent = PhoneNumber.order(created_at: :desc).first
    if recent
      number = recent.number
    else
      flash[:alert] = "Could not find a valid Indian phone number in your prompt, and no saved numbers are available."
      return redirect_to phone_numbers_path
    end
  end

  phone = PhoneNumber.find_or_initialize_by(number: number)
  phone.status ||= 'pending'
  phone.save if phone.new_record?

  twilio = TwilioService.new
  phone.update(status: 'calling')
  result = twilio.make_call(phone.number, message)

  if result[:success]
    phone.update(call_sid: result[:sid], called_at: Time.current)
    CallLog.create(phone_number: phone, status: 'queued', message: message, started_at: Time.current)
    flash[:notice] = "Calling #{phone.number} with: “#{message}”."
  else
    phone.update(status: 'failed')
    flash[:alert] = "Call failed: #{result[:error]}"
  end

  redirect_to phone_numbers_path
end


  private

  def set_phone_number
    @phone_number = PhoneNumber.find(params[:id])
  end
end
