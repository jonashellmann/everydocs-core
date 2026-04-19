class JsonWebToken
  HMAC_SECRET = Rails.configuration.secrets.secret_key_base
  DEFAULT_EXPIRY = 24.hours.from_now

  def self.encode(payload, exp = DEFAULT_EXPIRY)
    payload[:exp] = exp.to_i
    JWT.encode(payload, HMAC_SECRET)
  end

  def self.decode(token)
    body = JWT.decode(token, HMAC_SECRET)[0]
    HashWithIndifferentAccess.new(body)
  rescue JWT::ExpiredSignature => e
    raise ExceptionHandler::ExpiredToken, e.message
  rescue JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end

  def self.decode_without_expiry_validation(token)
    decoded = JWT.decode(token, HMAC_SECRET, true, { exp_leeway: Float::INFINITY })[0]
    HashWithIndifferentAccess.new(decoded)
  rescue JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end

  def self.valid_payload?(payload)
    return false unless payload.is_a?(Hash)
    return false unless payload[:user_id].present?
    
    exp = payload[:exp]
    return false unless exp.is_a?(Integer)
    
    exp > Time.current.to_i
  end
end
